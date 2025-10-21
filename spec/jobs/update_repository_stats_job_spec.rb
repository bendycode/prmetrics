require 'rails_helper'

RSpec.describe UpdateRepositoryStatsJob do
  let(:repository) { create(:repository) }
  let(:job) { described_class.new }

  describe '#perform' do
    before do
      # Create some pull requests with various dates
      create(:pull_request, repository: repository,
                            gh_created_at: 2.weeks.ago,
                            ready_for_review_at: 2.weeks.ago)
      create(:pull_request, repository: repository,
                            gh_created_at: 1.week.ago,
                            ready_for_review_at: 1.week.ago,
                            gh_merged_at: 3.days.ago)
    end

    it 'generates weeks for the repository' do
      expect(WeekStatsService).to receive(:generate_weeks_for_repository).with(repository)
      job.perform(repository.id)
    end

    it 'updates stats for each week' do
      job.perform(repository.id)

      # Should create at least 3 weeks (2 weeks ago, 1 week ago, current week)
      expect(repository.weeks.count).to be >= 3
    end

    it 'calls update_stats on each week' do
      # First generate the weeks
      WeekStatsService.generate_weeks_for_repository(repository)

      # Mock the update_stats calls
      repository.weeks.each do |week|
        service_double = instance_double(WeekStatsService)
        expect(WeekStatsService).to receive(:new).with(week).and_return(service_double)
        expect(service_double).to receive(:update_stats)
      end

      job.perform(repository.id)
    end

    it 'logs completion message' do
      expect(Rails.logger).to receive(:info).with("Updated stats for #{repository.name} and all related repositories")
      job.perform(repository.id)
    end

    context 'when repository does not exist' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect { job.perform(999_999) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when repository has no pull requests' do
      let(:empty_repository) { create(:repository) }

      it 'does not create any weeks' do
        job.perform(empty_repository.id)
        expect(empty_repository.weeks.count).to eq(0)
      end

      it 'still logs completion' do
        expect(Rails.logger).to receive(:info).with("Updated stats for #{empty_repository.name} and all related repositories")
        job.perform(empty_repository.id)
      end
    end
  end

  describe 'comprehensive stats updates' do
    let(:repo1) { create(:repository, name: 'owner/repo1') }
    let(:repo2) { create(:repository, name: 'owner/repo2') }
    let(:repo3) { create(:repository, name: 'owner/repo3') }

    before do
      # Create repositories with some pull requests
      [repo1, repo2, repo3].each do |repo|
        create(:pull_request, repository: repo, gh_created_at: 1.week.ago)
      end
    end

    it 'generates weeks for ALL repositories, not just the target one' do
      expect(WeekStatsService).to receive(:generate_weeks_for_repository).with(repo1)
      expect(WeekStatsService).to receive(:generate_weeks_for_repository).with(repo2)
      expect(WeekStatsService).to receive(:generate_weeks_for_repository).with(repo3)
      expect(WeekStatsService).to receive(:update_all_weeks)

      job.perform(repo1.id)
    end

    it 'updates statistics for ALL weeks across ALL repositories' do
      expect(WeekStatsService).to receive(:update_all_weeks)
      job.perform(repo1.id)
    end

    it 'calls cleanup for only the target repository' do
      expect(job).to receive(:cleanup_orphaned_data).with(repo1)
      job.perform(repo1.id)
    end

    it 'behaves like rake weeks:update_stats' do
      # This test verifies the job now does the same thing as the rake task
      # The rake task calls generate_weeks_for_repository for all repos, then update_all_weeks

      expect(Repository).to receive(:find_each).and_yield(repo1).and_yield(repo2).and_yield(repo3)
      expect(WeekStatsService).to receive(:generate_weeks_for_repository).with(repo1)
      expect(WeekStatsService).to receive(:generate_weeks_for_repository).with(repo2)
      expect(WeekStatsService).to receive(:generate_weeks_for_repository).with(repo3)
      expect(WeekStatsService).to receive(:update_all_weeks)

      job.perform(repo1.id)
    end
  end

  describe 'backward compatibility' do
    it 'still works when only one repository exists' do
      single_repo = create(:repository)
      allow(WeekStatsService).to receive(:generate_weeks_for_repository)
      allow(WeekStatsService).to receive(:update_all_weeks)

      expect {
        job.perform(single_repo.id)
      }.not_to raise_error

      # Should still update stats for the single repository
      expect(WeekStatsService).to have_received(:update_all_weeks)
    end
  end
end
