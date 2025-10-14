require 'rails_helper'

RSpec.describe 'Week Navigation', type: :system, js: true do
  let(:admin) { create(:user, :admin) }
  let(:repository) { create(:repository, name: 'test/repo') }
  let(:week) { create(:week, repository: repository, week_number: 202401, begin_date: Date.new(2024, 1, 8), end_date: Date.new(2024, 1, 14)) }

  before do
    sign_in admin
  end

  describe 'late and stale PRs functionality' do
    # Week ends January 14, 2024 - calculate approval dates relative to that
    let!(:fresh_pr) {
      pr = create(:pull_request, repository: repository, title: 'Fresh Feature',
                  gh_created_at: Date.new(2023, 12, 1))
      create(:review, pull_request: pr, state: 'APPROVED',
             submitted_at: week.end_date - 2.days) # Approved 2 days before week end
      pr
    }
    let!(:late_pr) {
      pr = create(:pull_request, repository: repository, title: 'Late Feature',
                  gh_created_at: Date.new(2023, 12, 1))
      create(:review, pull_request: pr, state: 'APPROVED',
             submitted_at: week.end_date - 10.days) # Approved 10 days before week end
      pr
    }
    let!(:stale_pr) {
      pr = create(:pull_request, repository: repository, title: 'Stale Feature',
                  gh_created_at: Date.new(2023, 12, 1))
      create(:review, pull_request: pr, state: 'APPROVED',
             submitted_at: week.end_date - 35.days) # Approved 35 days before week end
      pr
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
    it 'PR approved exactly 7 days before week end is NOT late' do
      pr = create(:pull_request, repository: repository, gh_created_at: Date.new(2023, 12, 1))
      create(:review, pull_request: pr, state: 'APPROVED', submitted_at: week.end_date - 7.days)
      WeekStatsService.new(week).update_stats
      visit repository_week_path(repository, week)
      expect(page).to have_content('Late PRs: 0')
    end

    it 'PR approved exactly 8 days before week end IS late' do
      pr = create(:pull_request, repository: repository, gh_created_at: Date.new(2023, 12, 1))
      create(:review, pull_request: pr, state: 'APPROVED', submitted_at: week.end_date - 8.days)
      WeekStatsService.new(week).update_stats
      visit repository_week_path(repository, week)
      expect(page).to have_content('Late PRs: 1')
    end

    it 'PR approved exactly 28 days before week end IS stale (not late)' do
      pr = create(:pull_request, repository: repository, gh_created_at: Date.new(2023, 12, 1))
      create(:review, pull_request: pr, state: 'APPROVED', submitted_at: week.end_date - 28.days)
      WeekStatsService.new(week).update_stats
      visit repository_week_path(repository, week)
      expect(page).to have_content('Late PRs: 0')
      expect(page).to have_content('Stale PRs: 1')
    end
  end
end