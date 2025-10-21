require 'rails_helper'

RSpec.describe 'Week Navigation', js: true do
  let(:admin) { create(:user, :admin) }
  let(:repository) { create(:repository, name: 'test/repo') }
  let(:week) {
    create(:week, repository: repository, week_number: 202_401, begin_date: Date.new(2024, 1, 8),
                  end_date: Date.new(2024, 1, 14))
  }

  before do
    sign_in admin
  end

  describe 'late and stale PRs functionality' do
    # Week ends January 14, 2024 - use factory trait for cleaner setup
    let!(:fresh_pr) {
      create(:pull_request, :approved_before_week_end,
             repository: repository, week: week, days_before_week_end: 2,
             title: 'Fresh Feature')
    }
    let!(:late_pr) {
      create(:pull_request, :approved_before_week_end,
             repository: repository, week: week, days_before_week_end: 10,
             title: 'Late Feature')
    }
    let!(:stale_pr) {
      create(:pull_request, :approved_before_week_end,
             repository: repository, week: week, days_before_week_end: 35,
             title: 'Stale Feature')
    }

    before do
      # Populate cached values
      WeekStatsService.new(week).update_stats
    end

    it 'displays late PR count from cached column' do
      visit repository_week_path(repository, week)
      expect(page).to have_content('Late PRs: 1')
    end

    it 'displays stale PR count from cached column' do
      visit repository_week_path(repository, week)
      expect(page).to have_content('Stale PRs: 1')
    end

    it 'allows viewing late PRs dynamically' do
      visit repository_week_path(repository, week)
      page.find('a[data-category="late"]').click
      expect(page).to have_content('Late Feature')
      expect(page).to have_no_content('Fresh Feature')
      expect(page).to have_no_content('Stale Feature')
    end

    it 'allows viewing stale PRs dynamically' do
      visit repository_week_path(repository, week)
      page.find('a[data-category="stale"]').click
      expect(page).to have_content('Stale Feature')
      expect(page).to have_no_content('Fresh Feature')
      expect(page).to have_no_content('Late Feature')
    end

    it 'does not show old "Approved but Unmerged PRs" line' do
      visit repository_week_path(repository, week)
      expect(page).to have_no_content('Approved but Unmerged PRs')
    end
  end

  describe 'boundary conditions' do
    it 'PR approved exactly 7 days before week end is NOT late' do
      create(:pull_request, :approved_before_week_end,
             repository: repository, week: week, days_before_week_end: 7)
      WeekStatsService.new(week).update_stats
      visit repository_week_path(repository, week)
      expect(page).to have_content('Late PRs: 0')
    end

    it 'PR approved exactly 8 days before week end IS late' do
      create(:pull_request, :approved_before_week_end,
             repository: repository, week: week, days_before_week_end: 8)
      WeekStatsService.new(week).update_stats
      visit repository_week_path(repository, week)
      expect(page).to have_content('Late PRs: 1')
    end

    it 'PR approved exactly 28 days before week end IS stale (not late)' do
      create(:pull_request, :approved_before_week_end,
             repository: repository, week: week, days_before_week_end: 28)
      WeekStatsService.new(week).update_stats
      visit repository_week_path(repository, week)
      expect(page).to have_content('Late PRs: 0')
      expect(page).to have_content('Stale PRs: 1')
    end
  end
end
