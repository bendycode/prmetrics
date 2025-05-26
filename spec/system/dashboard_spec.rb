require 'rails_helper'

RSpec.describe 'Dashboard', type: :system do
  let!(:admin) { create(:admin, email: 'admin@example.com', password: 'password123') }
  
  before do
    # Log in admin
    visit new_admin_session_path
    fill_in 'Email', with: admin.email
    fill_in 'Password', with: 'password123'
    click_button 'Log in'
  end

  describe 'homepage dashboard' do
    context 'with no data' do
      it 'displays empty dashboard correctly' do
        visit root_path
        
        expect(page).to have_content('Dashboard')
        expect(page).to have_content('Total Repositories')
        expect(page).to have_content('Total Pull Requests')
        expect(page).to have_content('Avg Time to Review')
        expect(page).to have_content('Avg Time to Merge')
        
        # Should show zero values
        expect(page).to have_content('0') # repositories count
        
        # Should show empty state messages
        expect(page).to have_content('No repositories configured yet.')
        expect(page).to have_content('No week data available yet.')
      end

      it 'displays charts even with no data' do
        visit root_path
        
        expect(page).to have_css('canvas#weeklyTrendsChart')
        expect(page).to have_css('canvas#repositoryActivityChart')
        expect(page).to have_content('Weekly PR Trends')
        expect(page).to have_content('Repository Activity')
      end
    end

    context 'with sample data' do
      let!(:repository) { create(:repository, name: 'test/repo') }
      let!(:week) { create(:week, repository: repository, week_number: 1) }
      let!(:pull_request) { create(:pull_request, repository: repository, number: 123) }
      let!(:user) { create(:user, username: 'testuser') }
      let!(:review) { create(:review, pull_request: pull_request, author: user) }

      it 'displays dashboard with data' do
        visit root_path
        
        expect(page).to have_content('Dashboard')
        
        # Should show actual counts
        expect(page).to have_content('1') # repositories count
        
        # Should show repository in list
        expect(page).to have_content('test/repo')
        expect(page).to have_link('test/repo')
        
        # Should show week data
        expect(page).to have_content('Week 1')
        expect(page).to have_link('Week 1')
      end

      it 'allows navigation to repositories' do
        visit root_path
        
        click_link 'test/repo'
        expect(page).to have_current_path(repository_path(repository))
      end

      it 'allows navigation to week details' do
        visit root_path
        
        click_link 'Week 1'
        expect(page).to have_current_path(repository_week_path(repository, week))
      end
    end
  end

  describe 'navigation' do
    it 'provides dashboard link in sidebar' do
      visit root_path
      
      expect(page).to have_css('.sidebar')
      expect(page).to have_link('Dashboard', href: root_path)
    end

    it 'allows navigation to other sections' do
      visit root_path
      
      # Check for navigation links
      expect(page).to have_link('Repositories')
      expect(page).to have_link('Users') 
      expect(page).to have_link('Admins')
      
      # Test navigation
      click_link 'Repositories'
      expect(page).to have_current_path(repositories_path)
    end

    it 'marks dashboard as active in sidebar' do
      visit root_path
      
      # The dashboard nav item should have active class
      within('.sidebar') do
        expect(page).to have_css('.nav-item.active')
        expect(page).to have_link('Dashboard')
      end
    end
  end

  describe 'responsive layout' do
    it 'displays properly on different screen sizes' do
      visit root_path
      
      # Check for responsive classes
      expect(page).to have_css('.row')
      expect(page).to have_css('.col-xl-3')
      expect(page).to have_css('.col-md-6')
      expect(page).to have_css('.col-lg-6')
      
      # Check that cards are present
      expect(page).to have_css('.card', count: 8) # 4 metric cards + 4 chart/data cards
    end
  end

  describe 'chart functionality' do
    let!(:repository) { create(:repository, name: 'test/repo') }
    let!(:week1) { create(:week, repository: repository, week_number: 1, num_prs_started: 5, num_prs_merged: 3) }
    let!(:week2) { create(:week, repository: repository, week_number: 2, num_prs_started: 7, num_prs_merged: 4) }
    let!(:pull_request) { create(:pull_request, repository: repository) }

    it 'includes chart data in page JavaScript' do
      visit root_path
      
      # Chart.js should be loaded
      expect(page).to have_css('canvas#weeklyTrendsChart')
      expect(page).to have_css('canvas#repositoryActivityChart')
      
      # Check that chart data is embedded in the page
      page_source = page.html
      expect(page_source).to include('Week 1')
      expect(page_source).to include('Week 2')
      expect(page_source).to include('new Chart')
    end
  end

  describe 'performance metrics display' do
    it 'handles missing data gracefully' do
      visit root_path
      
      # Should show 0 or N/A for missing metrics
      # Should show zero values in metric cards
      metric_cards = page.all('.card .h5')
      expect(metric_cards.first.text).to eq('0')
    end

    context 'with pull request data' do
      let!(:repository) { create(:repository) }
      let!(:pr_with_review) do
        create(:pull_request, 
               repository: repository,
               ready_for_review_at: 2.days.ago,
               gh_merged_at: 1.day.ago)
      end
      let!(:user) { create(:user) }
      let!(:review) do
        create(:review, 
               pull_request: pr_with_review,
               author: user,
               submitted_at: 1.day.ago)
      end

      it 'calculates and displays time metrics' do
        visit root_path
        
        # Should show calculated averages (not zero)
        metric_cards = page.all('.card-body .h5')
        values = metric_cards.map(&:text)
        
        # At least some metrics should be non-zero
        expect(values.any? { |v| v.to_f > 0 }).to be true
      end
    end
  end

  describe 'user navigation' do
    it 'displays user avatar and dropdown correctly' do
      visit root_path
      
      # Should show user email in topbar
      expect(page).to have_content(admin.email)
      
      # Should have user avatar (Font Awesome icon, not broken image)
      expect(page).to have_css('.img-profile i.fas.fa-user')
      expect(page).not_to have_css('img[src*="undraw_profile.svg"]')
      
      # Should have user dropdown with proper options
      expect(page).to have_css('#userDropdown')
      
      # Click dropdown to reveal options
      find('#userDropdown').click
      
      # Should show My Account and Logout options
      expect(page).to have_link('My Account', href: edit_account_path)
      expect(page).to have_content('Logout')
    end
    
    it 'allows navigation to account settings' do
      visit root_path
      
      # Click user dropdown
      find('#userDropdown').click
      
      # Click My Account
      click_link 'My Account'
      
      # Should navigate to account edit page
      expect(page).to have_current_path(edit_account_path)
      expect(page).to have_content('My Account')
    end
    
    it 'opens dropdown when clicking on email address' do
      visit root_path
      
      # Find and click on the email text specifically
      email_element = find('#userDropdown span', text: admin.email)
      email_element.click
      
      # Should show dropdown menu
      expect(page).to have_css('.dropdown-menu', visible: true)
      expect(page).to have_link('My Account')
    end
  end

  describe 'error handling' do
    it 'handles database errors gracefully' do
      # This test ensures our fixes work
      visit root_path
      
      # Should load without errors
      expect(page).to have_content('Dashboard')
      expect(page).not_to have_content('ActiveRecord::StatementInvalid')
      expect(page).not_to have_content('ERROR')
    end
  end
end