require 'rails_helper'

RSpec.describe UpdateRepositoryStatsJob, type: :job do
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
      expect(Rails.logger).to receive(:info).with("Updated stats for #{repository.name}")
      job.perform(repository.id)
    end

    context 'when repository does not exist' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect { job.perform(999999) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when repository has no pull requests' do
      let(:empty_repository) { create(:repository) }

      it 'does not create any weeks' do
        job.perform(empty_repository.id)
        expect(empty_repository.weeks.count).to eq(0)
      end

      it 'still logs completion' do
        expect(Rails.logger).to receive(:info).with("Updated stats for #{empty_repository.name}")
        job.perform(empty_repository.id)
      end
    end
  end
end