require 'rails_helper'

RSpec.describe 'Repository Sync Integration' do
  include ActiveJob::TestHelper
  let(:admin) { create(:user, :admin) }
  let(:repository) { create(:repository) }

  before do
    sign_in admin
  end

  describe 'sync button on repository show page' do
    it 'triggers the sync job and ensures UpdateRepositoryStatsJob works' do
      # Create some test data that will be used by UpdateRepositoryStatsJob
      create(:pull_request, repository: repository,
             gh_created_at: 1.week.ago,
             ready_for_review_at: 1.week.ago)

      visit repository_path(repository)

      # The sync button should exist
      expect(page).to have_button('Sync Updates')

      # Click sync should queue the job
      expect {
        click_button 'Sync Updates'
      }.to have_enqueued_job(SyncRepositoryBatchJob)

      # Should redirect with success message
      expect(page).to have_content("Sync job queued for #{repository.name}")

      # Most importantly: verify UpdateRepositoryStatsJob can be called without ArgumentError
      # This is what would have caught the bug
      expect {
        UpdateRepositoryStatsJob.new.perform(repository.id)
      }.not_to raise_error

      # And it should create weeks
      repository.reload
      expect(repository.weeks.count).to be >= 2 # At least current week and 1 week ago
    end
  end

  describe 'full sync button' do
    it 'passes fetch_all parameter correctly' do
      visit repository_path(repository)

      # Full sync button should queue with fetch_all: true
      expect {
        click_button 'Full Sync'
      }.to have_enqueued_job(SyncRepositoryBatchJob)
        .with(repository.name, page: 1, fetch_all: true)
    end
  end
end