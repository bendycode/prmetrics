require 'rails_helper'

RSpec.describe 'Dashboard Late and Stale PRs Chart', type: :system, js: true do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  describe 'PR Velocity Trends chart displays late and stale PRs datasets' do
    context 'with late and stale PRs data from multiple weeks' do
      let(:repository) { create(:repository, name: 'test/repo') }
      let!(:week1) { create(:week, repository: repository, week_number: 202401, begin_date: Date.new(2024, 1, 8), end_date: Date.new(2024, 1, 14)) }
      let!(:week2) { create(:week, repository: repository, week_number: 202402, begin_date: Date.new(2024, 1, 15), end_date: Date.new(2024, 1, 21)) }

      before do
        # Week 1: 1 late PR, 1 stale PR
        create(:pull_request, :approved_days_ago, days_ago: 10, repository: repository, gh_created_at: week1.begin_date)
        create(:pull_request, :approved_days_ago, days_ago: 35, repository: repository, gh_created_at: week1.begin_date)

        # Week 2: 2 late PRs, 1 stale PR
        create_list(:pull_request, 2, :approved_days_ago, days_ago: 15, repository: repository, gh_created_at: week2.begin_date)
        create(:pull_request, :approved_days_ago, days_ago: 40, repository: repository, gh_created_at: week2.begin_date)

        # Fresh PR (not late or stale)
        create(:pull_request, :approved_days_ago, days_ago: 3, repository: repository, gh_created_at: week1.begin_date)

        # Populate cached values
        WeekStatsService.new(week1).update_stats
        WeekStatsService.new(week2).update_stats
      end

      it 'shows Late PRs dataset in chart on main dashboard' do
        visit root_path

        expect(page).to have_content('PR Velocity Trends')
        expect(page).to have_css('canvas#prVelocityChart')
        expect(page.html).to include('Late PRs')
      end

      it 'shows Stale PRs dataset in chart on main dashboard' do
        visit root_path

        expect(page).to have_content('PR Velocity Trends')
        expect(page).to have_css('canvas#prVelocityChart')
        expect(page.html).to include('Stale PRs')
      end

      it 'does not show old PRs Approved dataset' do
        visit root_path

        expect(page).to have_content('PR Velocity Trends')
        expect(page.html).not_to include('PRs Approved')
      end

      it 'shows late and stale PRs in chart on repository filtered dashboard' do
        visit dashboard_path(repository_id: repository.id)

        expect(page).to have_content('PR Velocity Trends')
        expect(page).to have_css('canvas#prVelocityChart')
        expect(page.html).to include('Late PRs')
        expect(page.html).to include('Stale PRs')
        expect(page).to have_content("for #{repository.name}")
      end
    end

    context 'with no late or stale PRs' do
      let(:repository) { create(:repository, name: 'test/repo') }
      let!(:week) { create(:week, repository: repository, week_number: 202401, begin_date: Date.new(2024, 1, 8), end_date: Date.new(2024, 1, 14)) }

      before do
        # Only fresh PRs (approved within last week)
        create(:pull_request, :approved_days_ago, days_ago: 3, repository: repository, gh_created_at: week.begin_date)
        WeekStatsService.new(week).update_stats
      end

      it 'still shows late and stale PRs datasets with zero values' do
        visit root_path

        expect(page).to have_content('PR Velocity Trends')
        expect(page).to have_css('canvas#prVelocityChart')
        expect(page.html).to include('Late PRs')
        expect(page.html).to include('Stale PRs')
      end
    end
  end
end
