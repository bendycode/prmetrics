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
end