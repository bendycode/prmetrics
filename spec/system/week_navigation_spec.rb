require 'rails_helper'

RSpec.describe 'Week Navigation', type: :system, js: true do
  let(:admin) { create(:user, :admin) }
  let(:repository) { create(:repository, name: 'test/repo') }
  let(:week) { create(:week, repository: repository, week_number: 202401, begin_date: Date.new(2024, 1, 8), end_date: Date.new(2024, 1, 14)) }

  before do
    sign_in admin
  end

  describe 'approved PRs functionality' do
    let!(:approved_pr) { create(:pull_request, :approved, repository: repository, title: 'Approved Feature', gh_created_at: week.begin_date) }
    let!(:unapproved_pr) { create(:pull_request, :with_comments, repository: repository, title: 'Unapproved Feature', gh_created_at: week.begin_date) }

    it 'displays approved PR count and allows viewing approved PRs' do
      visit repository_week_path(repository, week)

      expect(page).to have_content('Approved but Unmerged PRs: 1')
      expect(page).to have_link('View PRs', href: '#')

      # Click the "View PRs" link for approved category
      page.find('a[data-category="approved"]').click

      # Wait for the AJAX response
      expect(page).to have_content('Approved Feature')
      expect(page).not_to have_content('Unapproved Feature')
    end

    it 'handles empty approved PRs list' do
      # Remove the approved review
      approved_pr.reviews.destroy_all

      visit repository_week_path(repository, week)

      expect(page).to have_content('Approved but Unmerged PRs: 0')

      page.find('a[data-category="approved"]').click

      # Should show empty state or no content
      expect(page).not_to have_content('Approved Feature')
    end
  end

  describe 'integration with other PR categories' do
    let!(:unapproved_open_pr) { create(:pull_request, :with_comments, repository: repository, title: 'Unapproved Open PR', gh_created_at: week.begin_date) }
    let!(:approved_open_pr) { create(:pull_request, :approved, repository: repository, title: 'Approved Open PR', gh_created_at: week.begin_date) }

    it 'allows switching between different PR categories' do
      visit repository_week_path(repository, week)

      # Check initial counts - both PRs are open, but only one is approved
      expect(page).to have_content('Open PRs: 2')
      expect(page).to have_content('Approved but Unmerged PRs: 1')

      # View open PRs - should show both
      page.find('a[data-category="open"]').click
      expect(page).to have_content('Unapproved Open PR')
      expect(page).to have_content('Approved Open PR')

      # Switch to approved PRs - should show only the approved one
      page.find('a[data-category="approved"]').click
      expect(page).to have_content('Approved Open PR')
      expect(page).not_to have_content('Unapproved Open PR')
    end
  end

  describe 'late and stale PRs functionality' do
    let!(:fresh_pr) {
      create(:pull_request, :approved_days_ago, days_ago: 2, repository: repository,
             title: 'Fresh Feature', gh_created_at: week.begin_date)
    }
    let!(:late_pr) {
      create(:pull_request, :approved_days_ago, days_ago: 10, repository: repository,
             title: 'Late Feature', gh_created_at: week.begin_date)
    }
    let!(:stale_pr) {
      create(:pull_request, :approved_days_ago, days_ago: 35, repository: repository,
             title: 'Stale Feature', gh_created_at: week.begin_date)
    }

    before do
      # Populate cached values
      WeekStatsService.new(week).update_stats
    end

    it 'displays late PR count from cached column' do
      visit repository_week_path(repository, week)
      expect(page).to have_content('Late PRs (> 1 week, < 4 weeks): 1')
    end

    it 'displays stale PR count from cached column' do
      visit repository_week_path(repository, week)
      expect(page).to have_content('Stale PRs (≥ 4 weeks): 1')
    end

    it 'allows viewing late PRs dynamically' do
      visit repository_week_path(repository, week)
      page.find('a[data-category="late"]').click
      expect(page).to have_content('Late Feature')
      expect(page).not_to have_content('Fresh Feature')
      expect(page).not_to have_content('Stale Feature')
    end

    it 'allows viewing stale PRs dynamically' do
      visit repository_week_path(repository, week)
      page.find('a[data-category="stale"]').click
      expect(page).to have_content('Stale Feature')
      expect(page).not_to have_content('Fresh Feature')
      expect(page).not_to have_content('Late Feature')
    end

    it 'does not show old "Approved but Unmerged PRs" line' do
      visit repository_week_path(repository, week)
      expect(page).not_to have_content('Approved but Unmerged PRs')
    end
  end

  describe 'boundary conditions' do
    it 'PR approved exactly 7 days ago is NOT late' do
      create(:pull_request, :approved_days_ago, days_ago: 7, repository: repository,
             gh_created_at: week.begin_date)
      WeekStatsService.new(week).update_stats
      visit repository_week_path(repository, week)
      expect(page).to have_content('Late PRs (> 1 week, < 4 weeks): 0')
    end

    it 'PR approved exactly 8 days ago IS late' do
      create(:pull_request, :approved_days_ago, days_ago: 8, repository: repository,
             gh_created_at: week.begin_date)
      WeekStatsService.new(week).update_stats
      visit repository_week_path(repository, week)
      expect(page).to have_content('Late PRs (> 1 week, < 4 weeks): 1')
    end

    it 'PR approved exactly 28 days ago IS stale (not late)' do
      create(:pull_request, :approved_days_ago, days_ago: 28, repository: repository,
             gh_created_at: week.begin_date)
      WeekStatsService.new(week).update_stats
      visit repository_week_path(repository, week)
      expect(page).to have_content('Late PRs (> 1 week, < 4 weeks): 0')
      expect(page).to have_content('Stale PRs (≥ 4 weeks): 1')
    end
  end
end