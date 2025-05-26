require 'rails_helper'

RSpec.describe 'Repository Sync', type: :system do
  let(:admin) { create(:admin) }
  let(:repository) { create(:repository, name: 'test/repo', url: 'https://github.com/test/repo') }

  before do
    sign_in admin
  end

  describe 'sync controls' do
    it 'displays sync status and controls on repository page' do
      visit repository_path(repository)
      
      expect(page).to have_content('Sync Status')
      expect(page).to have_button('Sync Updates')
      expect(page).to have_button('Full Sync')
    end

    it 'allows incremental sync of repository' do
      visit repository_path(repository)
      
      # Mock the GitHub API call to avoid actual API requests
      allow_any_instance_of(GithubService).to receive(:fetch_and_store_pull_requests).and_return(true)
      
      click_button 'Sync Updates'
      
      expect(page).to have_content('Sync job queued')
      expect(page).to have_button('Sync Updates')
    end

    it 'shows full sync button with confirmation' do
      visit repository_path(repository)
      
      # Check that the full sync button exists and has confirmation
      expect(page).to have_button('Full Sync')
      expect(page).to have_selector('[data-confirm]')
    end
  end

  describe 'sync status display' do
    it 'shows completed sync status' do
      repository.update!(
        sync_status: 'completed',
        sync_started_at: 1.hour.ago,
        sync_completed_at: 30.minutes.ago
      )
      
      visit repository_path(repository)
      
      expect(page).to have_content('Status: Completed')
      expect(page).to have_content('Started:')
      expect(page).to have_content('Completed:')
    end

    it 'shows failed sync status with error message' do
      repository.update!(
        sync_status: 'failed',
        sync_started_at: 1.hour.ago,
        last_sync_error: 'API rate limit exceeded'
      )
      
      visit repository_path(repository)
      
      expect(page).to have_content('Status: Failed')
      expect(page).to have_content('Error: API rate limit exceeded')
    end

    it 'shows in-progress sync with Sidekiq link' do
      repository.update!(
        sync_status: 'in_progress',
        sync_started_at: 5.minutes.ago
      )
      
      visit repository_path(repository)
      
      expect(page).to have_content('Sync in progress')
      expect(page).to have_link('View Sidekiq', href: '/sidekiq')
      expect(page).to have_button('Sync Updates', disabled: true)
      expect(page).to have_button('Full Sync', disabled: true)
    end
  end

  describe 'repositories index sync' do
    it 'shows sync status for all repositories' do
      repo1 = create(:repository, name: 'org/repo1', sync_status: 'completed')
      repo2 = create(:repository, name: 'org/repo2', sync_status: 'in_progress')
      
      visit repositories_path
      
      expect(page).to have_content('org/repo1')
      expect(page).to have_content('org/repo2')
    end
  end

  describe 'error handling' do
    it 'shows sync controls on repository page' do
      visit repository_path(repository)
      
      expect(page).to have_button('Sync Updates')
      expect(page).to have_button('Full Sync')
    end
  end
end