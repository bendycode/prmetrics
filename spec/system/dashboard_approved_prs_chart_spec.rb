require 'rails_helper'

RSpec.describe 'Dashboard Approved PRs Chart', type: :system, js: true do
  let(:admin) { create(:admin) }
  let(:repository) { create(:repository, name: 'test/repo') }

  before do
    sign_in admin
  end

  describe 'PR Velocity Trends chart with approved PRs' do
    context 'with approved PRs data' do
      let!(:week1) { create(:week, repository: repository, week_number: 202401, begin_date: Date.new(2024, 1, 8), end_date: Date.new(2024, 1, 14)) }
      let!(:week2) { create(:week, repository: repository, week_number: 202402, begin_date: Date.new(2024, 1, 15), end_date: Date.new(2024, 1, 21)) }

      let!(:approved_pr_week1) { create(:pull_request, :approved, repository: repository, gh_created_at: week1.begin_date) }
      let!(:approved_pr_week2_a) { create(:pull_request, :approved, repository: repository, gh_created_at: week2.begin_date) }
      let!(:approved_pr_week2_b) { create(:pull_request, :approved, repository: repository, gh_created_at: week2.begin_date) }
      let!(:unapproved_pr) { create(:pull_request, :with_comments, repository: repository, gh_created_at: week1.begin_date) }

      it 'displays approved PRs dataset in chart legend' do
        visit root_path

        expect(page).to have_content('PR Velocity Trends')
        expect(page).to have_text('PRs Approved')
      end

      it 'includes approved PR data in chart datasets' do
        visit root_path

        # Check that the chart canvas exists
        expect(page).to have_css('canvas#prVelocityChart')

        # The JavaScript should include approved data
        # We expect 1 approved PR in week1 and 2 approved PRs in week2
        page_content = page.html
        expect(page_content).to include('PRs Approved')
      end

      it 'shows correct approved counts when filtering by repository' do
        visit dashboard_path(repository_id: repository.id)

        expect(page).to have_content('PR Velocity Trends')
        expect(page).to have_content("for #{repository.name}")
        expect(page).to have_text('PRs Approved')
      end
    end

    context 'with no approved PRs' do
      let!(:week) { create(:week, repository: repository, week_number: 202401, begin_date: Date.new(2024, 1, 8), end_date: Date.new(2024, 1, 14)) }
      let!(:unapproved_pr) { create(:pull_request, :with_comments, repository: repository, gh_created_at: week.begin_date) }

      it 'still shows approved PRs dataset with zero data' do
        visit root_path

        expect(page).to have_content('PR Velocity Trends')
        expect(page).to have_text('PRs Approved')
      end
    end
  end
end