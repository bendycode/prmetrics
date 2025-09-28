require 'rails_helper'

RSpec.describe 'Dashboard Approved PRs Chart', type: :system, js: true do
  let(:admin) { create(:admin) }
  let(:repository) { create(:repository, name: 'test/repo') }

  before { sign_in admin }

  shared_examples 'displays approved PRs in chart' do
    it 'includes PRs Approved dataset in chart legend and data' do
      expect(page).to have_content('PR Velocity Trends')
      expect(page).to have_css('canvas#prVelocityChart')
      expect(page.html).to include('PRs Approved')
    end
  end

  describe 'PR Velocity Trends chart with approved PRs' do
    context 'with approved PRs data' do
      let!(:weeks) { create_list(:week, 2, repository: repository).tap do |weeks|
        weeks[0].update!(week_number: 202401, begin_date: Date.new(2024, 1, 8), end_date: Date.new(2024, 1, 14))
        weeks[1].update!(week_number: 202402, begin_date: Date.new(2024, 1, 15), end_date: Date.new(2024, 1, 21))
      end }

      before do
        # Create test data: 1 approved PR in week1, 2 approved PRs in week2, 1 unapproved
        create(:pull_request, :approved, repository: repository, gh_created_at: weeks[0].begin_date)
        create_list(:pull_request, 2, :approved, repository: repository, gh_created_at: weeks[1].begin_date)
        create(:pull_request, :with_comments, repository: repository, gh_created_at: weeks[0].begin_date)
      end

      describe 'dashboard view' do
        before { visit root_path }
        include_examples 'displays approved PRs in chart'
      end

      describe 'repository filtered view' do
        before { visit dashboard_path(repository_id: repository.id) }

        include_examples 'displays approved PRs in chart'

        it 'shows repository-specific context' do
          expect(page).to have_content("for #{repository.name}")
        end
      end
    end

    context 'with no approved PRs' do
      before do
        create(:week, repository: repository, week_number: 202401, begin_date: Date.new(2024, 1, 8), end_date: Date.new(2024, 1, 14))
        create(:pull_request, :with_comments, repository: repository, gh_created_at: Date.new(2024, 1, 8))
        visit root_path
      end

      include_examples 'displays approved PRs in chart'
    end
  end
end