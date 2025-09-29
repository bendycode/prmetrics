require 'rails_helper'

RSpec.describe 'Pull Request Navigation', type: :system do
  let(:admin) { create(:user, :admin) }
  let(:repository) { create(:repository, name: 'test/repo') }
  let(:github_user) { create(:github_user, username: 'testuser') }
  let(:user) { create(:contributor, username: 'reviewer1') }
  
  before do
    sign_in admin
  end

  describe 'pull requests index' do
    let!(:pull_requests) do
      [
        create(:pull_request, 
          repository: repository, 
          title: 'First PR', 
          state: 'open',
          gh_created_at: 2.days.ago),
        create(:pull_request, 
          repository: repository, 
          title: 'Second PR', 
          state: 'merged',
          gh_created_at: 1.day.ago)
      ]
    end

    it 'displays all pull requests for a repository' do
      visit repository_pull_requests_path(repository)
      
      expect(page).to have_content("Pull Requests for #{repository.name}")
      expect(page).to have_link('First PR')
      expect(page).to have_link('Second PR')
    end

    it 'allows navigation from repository to pull requests list' do
      visit repository_path(repository)
      
      click_link 'All Pull Requests'
      
      expect(page).to have_current_path(repository_pull_requests_path(repository))
      expect(page).to have_content("Pull Requests for #{repository.name}")
    end

    it 'paginates pull requests when there are many' do
      # Create enough PRs to trigger pagination (assuming 25 per page)
      30.times do |i|
        create(:pull_request, repository: repository, title: "PR #{i}")
      end
      
      visit repository_pull_requests_path(repository)
      
      expect(page).to have_css('.pagination')
    end
  end

  describe 'pull request details' do
    let(:pull_request) do
      create(:pull_request, 
        repository: repository,
        title: 'Test PR',
        state: 'merged',
        gh_created_at: 3.days.ago,
        ready_for_review_at: 3.days.ago,
        gh_merged_at: 1.day.ago,
        author: github_user)
    end
    
    let!(:review) do
      create(:review,
        pull_request: pull_request,
        author: user,
        state: 'approved',
        submitted_at: 2.days.ago)
    end
    
    let!(:pull_request_user) do
      create(:pull_request_user,
        pull_request: pull_request,
        user: user,
        role: 'reviewer')
    end

    it 'displays pull request details correctly' do
      visit pull_request_path(pull_request)
      
      expect(page).to have_content('Test PR')
      expect(page).to have_content('Pull Request Details')
      expect(page).to have_content('State: Merged')
      expect(page).to have_content('Created at:')
      expect(page).to have_content('Ready for review at:')
      expect(page).to have_content('Merged at:')
    end

    it 'displays review information' do
      visit pull_request_path(pull_request)
      
      expect(page).to have_content('Reviews')
      expect(page).to have_content('Author: reviewer1')
      expect(page).to have_content('State: Approved')
      expect(page).to have_content('Submitted at:')
    end

    it 'displays associated users and their roles' do
      visit pull_request_path(pull_request)
      
      expect(page).to have_content('Users')
      expect(page).to have_link('reviewer1')
      expect(page).to have_content('(reviewer)')
    end

    it 'allows navigation to user details' do
      visit pull_request_path(pull_request)
      
      click_link 'reviewer1'
      
      expect(page).to have_current_path(contributor_path(user))
      expect(page).to have_content(user.username)
    end

    it 'allows navigation to all pull request users' do
      visit pull_request_path(pull_request)
      
      click_link 'All GitHub Users'
      
      expect(page).to have_current_path(pull_request_pull_request_users_path(pull_request))
    end

    it 'displays timing metrics when available' do
      visit pull_request_path(pull_request)
      
      expect(page).to have_content('Time to first review:')
      expect(page).to have_content('Time to merge:')
    end
  end

  describe 'navigation between views' do
    let!(:pull_request) { create(:pull_request, repository: repository, title: 'Navigation Test') }

    it 'allows seamless navigation between repository and PR views' do
      # Start at repositories index
      visit repositories_path
      expect(page).to have_link(repository.name)
      
      # Go to repository details
      click_link repository.name
      expect(page).to have_current_path(repository_path(repository))
      
      # Go to PR list
      click_link 'All Pull Requests'
      expect(page).to have_current_path(repository_pull_requests_path(repository))
      
      # Go to specific PR
      click_link pull_request.title
      expect(page).to have_current_path(pull_request_path(pull_request))
    end
  end

  describe 'error handling' do
    it 'handles non-existent pull request gracefully' do
      visit "/pull_requests/99999"
      
      expect(page).to have_content('Record not found') 
      # Note: This depends on Rails error handling - might need adjustment
    end

    it 'handles pull request with missing data' do
      pr = create(:pull_request, 
        repository: repository, 
        title: 'Incomplete PR',
        ready_for_review_at: nil,
        gh_merged_at: nil)
      
      visit pull_request_path(pr)
      
      expect(page).to have_content('Incomplete PR')
      # Should not crash when timing data is missing
      expect(page).to have_content('Pull Request Details')
    end
  end

  describe 'search and filtering' do
    let!(:open_pr) { create(:pull_request, repository: repository, title: 'Open Feature', state: 'open') }
    let!(:merged_pr) { create(:pull_request, repository: repository, title: 'Merged Feature', state: 'merged') }

    it 'shows all PRs by default on repository PR list' do
      visit repository_pull_requests_path(repository)
      
      expect(page).to have_link('Open Feature')
      expect(page).to have_link('Merged Feature')
    end
  end
end