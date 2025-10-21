require 'rails_helper'

RSpec.describe UnifiedSyncService do
  let(:repo_name) { 'rails/rails' }
  let(:repository) { create(:repository, name: repo_name) }
  let(:github_service) { instance_double(GithubService) }

  before do
    allow(Repository).to receive(:find_or_create_by).with(name: repo_name).and_return(repository)
    allow(GithubService).to receive(:new).and_return(github_service)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('GITHUB_ACCESS_TOKEN').and_return('test_token')
  end

  describe '#sync!' do
    let(:service) { described_class.new(repo_name, progress_callback: ->(msg) {}) }
    let(:pr_data) { double(number: 123, created_at: 1.week.ago, merged_at: 2.days.ago) }
    let(:pull_request) {
      create(:pull_request, repository: repository, number: 123,
                            gh_created_at: 1.week.ago, gh_merged_at: 2.days.ago)
    }

    before do
      allow(github_service).to receive(:get_pull_request_count).and_return(10)
      allow(github_service).to receive(:fetch_and_store_pull_requests)
      allow(github_service).to receive(:fetch_recent_review_activity).and_return(0)
      allow(repository).to receive(:pull_requests).and_return(PullRequest.where(repository: repository))
    end

    it 'updates repository sync status during the process' do
      expect(repository).to receive(:update).with(
        sync_status: 'in_progress',
        sync_started_at: anything,
        sync_progress: 0
      )

      expect(repository).to receive(:update).with(
        sync_status: 'completed',
        sync_completed_at: anything,
        last_sync_error: nil,
        sync_progress: 100
      )

      service.sync!
    end

    it 'fetches PRs with a processor callback' do
      expect(github_service).to receive(:fetch_and_store_pull_requests).with(
        repo_name,
        fetch_all: false,
        processor: anything
      )

      service.sync!
    end

    it 'creates weeks for processed pull requests' do
      # Set up the PR to be found when processor is called
      allow(repository.pull_requests).to receive(:find_by).with(number: 123).and_return(pull_request)

      # Capture the processor and call it
      processor = nil
      allow(github_service).to receive(:fetch_and_store_pull_requests) do |name, opts|
        processor = opts[:processor]
      end

      expect {
        service.sync!
        processor.call(pr_data) if processor
      }.to change { repository.weeks.count }.by_at_least(1)
    end

    it 'updates week statistics for affected weeks' do
      create(:week, repository: repository)
      allow(service).to receive(:update_week_statistics)

      service.sync!

      expect(service).to have_received(:update_week_statistics)
    end

    context 'when sync fails' do
      before do
        allow(github_service).to receive(:fetch_and_store_pull_requests).and_raise(StandardError, 'API error')
      end

      it 'updates repository with failed status' do
        # Allow the initial in_progress update
        allow(repository).to receive(:update).with(
          sync_status: 'in_progress',
          sync_started_at: anything,
          sync_progress: 0
        )

        expect(repository).to receive(:update).with(
          sync_status: 'failed',
          sync_completed_at: anything,
          last_sync_error: 'API error'
        )

        expect { service.sync! }.to raise_error(StandardError, 'API error')
      end
    end

    context 'with fetch_all option' do
      let(:service) { described_class.new(repo_name, fetch_all: true, progress_callback: ->(msg) {}) }

      it 'passes fetch_all to github service' do
        expect(github_service).to receive(:fetch_and_store_pull_requests).with(
          repo_name,
          fetch_all: true,
          processor: anything
        )

        service.sync!
      end

      it 'gets total PR count from GitHub for progress tracking' do
        expect(github_service).to receive(:get_pull_request_count).with(repo_name).and_return(50)

        service.sync!
      end
    end

    context 'with custom progress callback' do
      let(:progress_messages) { [] }
      let(:progress_callback) { ->(msg) { progress_messages << msg } }
      let(:service) { described_class.new(repo_name, progress_callback: progress_callback) }

      it 'calls the custom progress callback' do
        service.sync!

        expect(progress_messages).to include("Starting unified sync for #{repo_name}")
        expect(progress_messages).to include("Sync completed successfully!")
      end
    end
  end

  describe 'progress tracking' do
    let(:service) { described_class.new(repo_name, progress_callback: ->(msg) {}) }
    let(:pr_data) { double(number: 123) }
    let(:pull_request) { create(:pull_request, repository: repository, number: 123) }

    it 'updates sync_progress during PR processing' do
      allow(github_service).to receive(:get_pull_request_count).and_return(100)
      allow(github_service).to receive(:fetch_recent_review_activity).and_return(0)

      # Capture the processor and simulate PR processing
      processor = nil
      allow(github_service).to receive(:fetch_and_store_pull_requests) do |name, opts|
        processor = opts[:processor]
      end

      allow(repository.pull_requests).to receive(:find_by).with(number: 123).and_return(pull_request)

      # Expect progress updates
      expect(repository).to receive(:update_column).with(:sync_progress, anything).at_least(:once)

      service.sync!

      # Simulate processing a PR to trigger progress update
      processor.call(pr_data) if processor
    end
  end
end
