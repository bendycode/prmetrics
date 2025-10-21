require 'rails_helper'

RSpec.describe 'Dashboard' do
  let!(:admin) { create(:user, :admin, email: 'admin@example.com', password: 'password123') }

  before do
    # Log in admin
    visit new_user_session_path
    fill_in 'Email', with: admin.email
    fill_in 'Password', with: 'password123'
    click_button 'Sign in'
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

        expect(page).to have_css('canvas#prVelocityChart')
        expect(page).to have_css('canvas#reviewPerformanceChart')
        expect(page).to have_css('canvas#repositoryComparisonChart')
        expect(page).to have_content('PR Velocity Trends')
        expect(page).to have_content('Review Performance')
        expect(page).to have_content('Repository Performance Comparison')
      end
    end

    context 'with sample data' do
      let!(:repository) { create(:repository, name: 'test/repo') }
      let!(:week) { create(:week, repository: repository, week_number: 1) }
      let!(:pull_request) { create(:pull_request, repository: repository, number: 123) }
      let!(:user) { create(:contributor, username: 'testuser') }
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
      expect(page).to have_link('Contributors')
      expect(page).to have_link('Users')

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
      expect(page).to have_css('.card', count: 9) # 4 metric cards + 3 chart cards + 2 data cards
    end
  end

  describe 'enhanced chart functionality' do
    let!(:repository) { create(:repository, name: 'test/repo') }
    let!(:week1) do
      create(:week, repository: repository, week_number: 1, num_prs_started: 5, num_prs_merged: 3, num_prs_cancelled: 1,
                    avg_hrs_to_first_review: 8.5, avg_hrs_to_merge: 24.0)
    end
    let!(:week2) do
      create(:week, repository: repository, week_number: 2, num_prs_started: 7, num_prs_merged: 4, num_prs_cancelled: 0,
                    avg_hrs_to_first_review: 6.0, avg_hrs_to_merge: 18.5)
    end
    let!(:pull_request) { create(:pull_request, repository: repository) }

    it 'displays enhanced analytics charts' do
      visit root_path

      # Enhanced chart canvases should be present
      expect(page).to have_css('canvas#prVelocityChart')
      expect(page).to have_css('canvas#reviewPerformanceChart')
      expect(page).to have_css('canvas#repositoryComparisonChart')

      # Chart titles should be updated
      expect(page).to have_content('PR Velocity Trends')
      expect(page).to have_content('Review Performance')
      expect(page).to have_content('Repository Performance Comparison')
    end

    it 'includes velocity and performance data in charts' do
      visit root_path

      page_source = page.html

      # Should include PR velocity data
      expect(page_source).to include('PRs Started')
      expect(page_source).to include('PRs Merged')
      expect(page_source).to include('PRs Cancelled')

      # Should include review performance data
      expect(page_source).to include('Hours to First Review')
      expect(page_source).to include('Hours to Merge')

      # Should include repository comparison data
      expect(page_source).to include('Total PRs (4 weeks)')
      expect(page_source).to include('Avg Review Time (hours)')
      expect(page_source).to include('Merge Rate (%)')
    end

    it 'displays charts with proper Chart.js configuration' do
      visit root_path

      page_source = page.html
      expect(page_source).to include('new Chart')
      expect(page_source).to include('responsive: true')
      expect(page_source).to include('maintainAspectRatio: false')
    end

    it 'uses consistent color scheme across charts and cards' do
      visit root_path

      page_source = page.html

      # Check color consistency documentation
      expect(page_source).to include('Dashboard Color Scheme')
      expect(page_source).to include('Blue (#4e73df): PR Counts/Volume')
      expect(page_source).to include('Yellow (#f6c23e): Review Time')
      expect(page_source).to include('Green (#1cc88a): Merge Time/Success')
      expect(page_source).to include('Red (#e74a3b): Cancelled/Failed PRs')
      expect(page_source).to include('Cyan (#36b9cc): Repositories/Infrastructure')

      # Check cards use consistent colors
      expect(page).to have_css('.border-left-info') # Repositories card (cyan)
      expect(page).to have_css('.border-left-primary') # PR count card (blue)
      expect(page).to have_css('.border-left-warning') # Review time card (yellow)
      expect(page).to have_css('.border-left-success') # Merge time card (green)

      # Check charts use consistent colors
      expect(page_source).to include("borderColor: '#f6c23e'") # Review time in chart
      expect(page_source).to include("borderColor: '#1cc88a'") # Merge time in chart
      expect(page_source).to include("borderColor: '#e74a3b'") # Cancelled PRs
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
      let!(:user) { create(:contributor) }
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
      # Admin user should have shield icon
      expect(page).to have_css('.img-profile i.fas.fa-user-shield')
      expect(page).to have_no_css('img[src*="undraw_profile.svg"]')

      # Should have user dropdown with proper options
      expect(page).to have_css('#userDropdown')

      # Click dropdown to reveal options
      find_by_id('userDropdown').click

      # Should show My Account and Logout options
      expect(page).to have_link('My Account', href: edit_account_path)
      expect(page).to have_content('Logout')
    end

    it 'allows navigation to account settings' do
      visit root_path

      # Click user dropdown
      find_by_id('userDropdown').click

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
      expect(page).to have_css('.dropdown-menu', visible: :visible)
      expect(page).to have_link('My Account')
    end

    it 'allows logout through modal' do
      visit root_path

      # Click user dropdown
      find_by_id('userDropdown').click

      # Click Logout to open modal
      within('#userDropdown + .dropdown-menu') do
        click_link 'Logout'
      end

      # Should show logout modal
      expect(page).to have_css('#logoutModal', visible: :visible)
      expect(page).to have_content('Ready to Leave?')

      # Click actual Logout button in modal
      within('#logoutModal') do
        click_link 'Logout'
      end

      # Should be redirected to login page
      expect(page).to have_current_path(new_user_session_path)
      expect(page).to have_content('Sign In')
    end
  end

  describe 'error handling' do
    it 'handles database errors gracefully' do
      # This test ensures our fixes work
      visit root_path

      # Should load without errors
      expect(page).to have_content('Dashboard')
      expect(page).to have_no_content('ActiveRecord::StatementInvalid')
      expect(page).to have_no_content('ERROR')
    end
  end
end
