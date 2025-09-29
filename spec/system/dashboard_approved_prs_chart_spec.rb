require 'rails_helper'

RSpec.describe 'Dashboard Approved PRs Chart', type: :system, js: true do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  describe 'PR Velocity Trends chart displays approved PRs dataset' do
    context 'with approved PRs data from multiple weeks' do
      let(:repository) { create(:repository, name: 'test/repo') }
      let!(:week1) { create(:week, repository: repository, week_number: 202401, begin_date: Date.new(2024, 1, 8), end_date: Date.new(2024, 1, 14)) }
      let!(:week2) { create(:week, repository: repository, week_number: 202402, begin_date: Date.new(2024, 1, 15), end_date: Date.new(2024, 1, 21)) }
      let!(:approved_pr_week1) { create(:pull_request, :approved, repository: repository, gh_created_at: week1.begin_date) }
      let!(:approved_prs_week2) { create_list(:pull_request, 2, :approved, repository: repository, gh_created_at: week2.begin_date) }
      let!(:unapproved_pr) { create(:pull_request, :with_comments, repository: repository, gh_created_at: week1.begin_date) }

      it 'shows approved PRs in chart on main dashboard' do
        visit root_path

        expect(page).to have_content('PR Velocity Trends')
        expect(page).to have_css('canvas#prVelocityChart')
        expect(page.html).to include('PRs Approved')
      end

      it 'shows approved PRs in chart on repository filtered dashboard' do
        visit dashboard_path(repository_id: repository.id)

        expect(page).to have_content('PR Velocity Trends')
        expect(page).to have_css('canvas#prVelocityChart')
        expect(page.html).to include('PRs Approved')
        expect(page).to have_content("for #{repository.name}")
      end
    end

    context 'with no approved PRs' do
      let(:repository) { create(:repository, name: 'test/repo') }
      let!(:week) { create(:week, repository: repository, week_number: 202401, begin_date: Date.new(2024, 1, 8), end_date: Date.new(2024, 1, 14)) }
      let!(:unapproved_pr) { create(:pull_request, :with_comments, repository: repository, gh_created_at: week.begin_date) }

      it 'still shows approved PRs dataset with zero values' do
        visit root_path

        expect(page).to have_content('PR Velocity Trends')
        expect(page).to have_css('canvas#prVelocityChart')
        expect(page.html).to include('PRs Approved')
      end
    end
  end
end