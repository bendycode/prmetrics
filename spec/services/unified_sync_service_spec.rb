require 'rails_helper'

RSpec.describe UnifiedSyncService do
  let(:repo_name) { 'rails/rails' }
  let!(:repository) { create(:repository, name: repo_name) }
  let(:github_service) { instance_double(GithubService) }
  let(:merged_at) { Time.zone.parse('2026-09-16 10:00') }
  let(:pr_data) { double(number: 123) }

  before do
    allow(GithubService).to receive(:new).and_return(github_service)
    allow(github_service).to receive_messages(get_pull_request_count: 10, fetch_recent_review_activity: 0,
                                              default_branch: 'main')
  end

  # Stands in for GithubService: stores the pull request, then hands its
  # GitHub data to the processor, as the real fetch does once per pull request.
  def fetch_stores_one_pull_request
    allow(github_service).to receive(:fetch_and_store_pull_requests) do |_name, processor:, **|
      create(:pull_request, repository: repository, number: 123,
                            gh_created_at: merged_at - 2.days, ready_for_review_at: merged_at - 2.days,
                            gh_merged_at: merged_at, gh_closed_at: merged_at, state: 'closed')
      processor.call(pr_data)
    end
  end

  describe '#sync!' do
    let(:service) { described_class.new(repo_name, progress_callback: ->(_msg) {}) }

    before { fetch_stores_one_pull_request }

    it 'marks the repository in progress while it fetches, then completed' do
      statuses = []
      allow(github_service).to receive(:fetch_and_store_pull_requests) do
        statuses << repository.reload.sync_status
      end

      service.sync!

      expect(statuses).to eq(['in_progress'])
      expect(repository.reload).to have_attributes(sync_status: 'completed', sync_progress: 100,
                                                   last_sync_error: nil)
    end

    it 'fetches incrementally with a processor by default' do
      service.sync!

      expect(github_service).to have_received(:fetch_and_store_pull_requests)
        .with(repo_name, fetch_all: false, processor: an_instance_of(Method))
    end

    it 'creates the weeks each pull request touches and refreshes their statistics' do
      service.sync!

      merged_week = repository.pull_requests.find_by(number: 123).merged_week
      expect(merged_week).to have_attributes(num_prs_merged: 1)
    end

    it "records the repository's current default branch from GitHub" do
      repository.update!(default_branch: 'master')

      service.sync!

      expect(repository.reload.default_branch).to eq('main')
    end

    context 'when an earlier pull request turns out to be a promotion' do
      let!(:earlier_deploy) do
        create(:pull_request, repository: repository, number: 7, head_ref: 'master', base_ref: 'production',
                              gh_created_at: merged_at - 20.days, gh_merged_at: merged_at - 19.days,
                              gh_closed_at: merged_at - 19.days, state: 'closed')
          .tap(&:ensure_weeks_exist_and_update_associations)
      end

      before do
        allow(github_service).to receive(:fetch_and_store_pull_requests) do |_name, processor:, **|
          create(:pull_request, repository: repository, number: 123, head_ref: 'main', base_ref: 'production')
          processor.call(pr_data)
        end
        allow(WeekStatsService).to receive(:new).and_call_original
      end

      it 'flags it and refreshes the statistics of the weeks it touched' do
        service.sync!

        expect(earlier_deploy.reload).to be_promotion
        expect(WeekStatsService).to have_received(:new).with(earlier_deploy.merged_week)
      end
    end

    context 'when the fetch fails' do
      before do
        allow(github_service).to receive(:fetch_and_store_pull_requests).and_raise(StandardError, 'API error')
      end

      it 'records the failure on the repository and re-raises' do
        expect { service.sync! }.to raise_error(StandardError, 'API error')

        expect(repository.reload).to have_attributes(sync_status: 'failed', last_sync_error: 'API error')
      end
    end

    context 'when the repository row no longer validates' do
      it 'fails the sync before fetching, and says so on the repository' do
        repository.name = 'not a repository name'
        repository.save(validate: false)
        invalid_service = described_class.new(repository.name, progress_callback: ->(_msg) {})

        expect { invalid_service.sync! }.to raise_error(ActiveRecord::RecordInvalid)
        expect(github_service).not_to have_received(:fetch_and_store_pull_requests)
        expect(repository.reload).to have_attributes(sync_status: 'failed')
      end
    end

    context 'with fetch_all option' do
      let(:service) { described_class.new(repo_name, fetch_all: true, progress_callback: ->(_msg) {}) }

      it 'fetches every pull request, sized by GitHub for progress tracking' do
        service.sync!

        expect(github_service).to have_received(:fetch_and_store_pull_requests)
          .with(repo_name, fetch_all: true, processor: an_instance_of(Method))
        expect(github_service).to have_received(:get_pull_request_count).with(repo_name)
      end
    end

    [nil, 0].each do |count|
      context "when GitHub's pull request count comes back as #{count.inspect}" do
        let(:service) { described_class.new(repo_name, fetch_all: true, progress_callback: ->(_msg) {}) }

        before { allow(github_service).to receive(:get_pull_request_count).and_return(count) }

        it 'still completes a full sync' do
          service.sync!

          expect(repository.reload).to have_attributes(sync_status: 'completed', last_sync_error: nil)
        end
      end
    end

    context "when counting GitHub's pull requests raises" do
      let(:service) { described_class.new(repo_name, fetch_all: true, progress_callback: ->(_msg) {}) }

      before { allow(github_service).to receive(:get_pull_request_count).and_raise(Octokit::ServerError) }

      it 'still completes a full sync' do
        service.sync!

        expect(repository.reload).to have_attributes(sync_status: 'completed', last_sync_error: nil)
      end
    end

    context 'with custom progress callback' do
      let(:progress_messages) { [] }
      let(:service) { described_class.new(repo_name, progress_callback: ->(msg) { progress_messages << msg }) }

      it 'reports the start and the finish' do
        service.sync!

        expect(progress_messages).to include("Starting unified sync for #{repo_name}", 'Sync completed successfully!')
      end
    end
  end

  describe '.new' do
    it 'refuses a name that is not a GitHub repository' do
      expect do
        described_class.new('not a repository name', progress_callback: ->(_msg) {})
      end.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'creates the repository on its first sync' do
      expect do
        described_class.new('rails/new-repo', progress_callback: ->(_msg) {})
      end.to change(Repository, :count).by(1)
    end
  end
end
