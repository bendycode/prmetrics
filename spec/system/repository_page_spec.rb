require 'rails_helper'

RSpec.describe 'Repository page' do
  let(:admin) { create(:user, :admin) }
  let(:repository) { create(:repository, name: 'test/repo') }

  before do
    sign_in admin
  end

  describe 'pull requests' do
    let!(:pull_request) do
      create(:pull_request, repository: repository, title: 'Some Pull Request Title')
    end

    it 'links to the pull requests index rather than listing them inline' do
      visit repository_path(repository)

      expect(page).to have_link('All Pull Requests', href: repository_pull_requests_path(repository))
      expect(page).to have_no_content(pull_request.title)
    end
  end

  describe 'the weeks table' do
    let!(:week) do
      create(:week, repository: repository,
                    begin_date: Date.new(2026, 8, 31),
                    end_date: Date.new(2026, 9, 6))
    end

    it 'shows the dates a week covers, not its week number' do
      visit repository_path(repository)

      expect(page.all('table thead th').map(&:text)).to eq(['Begin Date', 'End Date', 'Actions'])
      expect(page).to have_no_content('Week Number')
    end

    it 'sizes itself to its three columns rather than the full page width' do
      visit repository_path(repository)

      # Left at the width Bootstrap's .table takes by default, a row's first and
      # last cells sit at opposite edges of a wide screen and the eye loses which
      # cells belong together.
      expect(page).to have_table(class: %w[table w-auto])
    end

    it 'formats dates for reading rather than for sorting' do
      visit repository_path(repository)

      expect(page).to have_content('08/31/2026')
      expect(page).to have_content('09/06/2026')
      expect(page).to have_no_content('2026-08-31')
    end

    it 'links each week to its own page' do
      visit repository_path(repository)

      expect(page).to have_link(href: repository_week_path(repository, week), exact_text: 'Details')
    end
  end

  describe 'the weeks table when a repository outlives one page of weeks' do
    # A page holds 25 weeks, so 26 is the smallest number that splits across
    # two. Each week gets its own begin_date: the factory's is a constant, and
    # identical dates leave `order(begin_date: :desc)` free to return the rows
    # in any order at all, which would make the assertions below meaningless.
    let(:first_monday) { Date.new(2026, 1, 5) }
    let!(:weeks) do
      Array.new(26) do |offset|
        create(:week, repository: repository,
                      begin_date: first_monday + (offset * 7),
                      end_date: first_monday + (offset * 7) + 6)
      end
    end

    it 'shows the most recent 25 weeks first' do
      visit repository_path(repository)

      expect(page).to have_css('table tbody tr', count: 25)
      expect(page.all('table tbody tr td:first-child').map(&:text)).to eq(
        (1..25).map { |offset| (first_monday + ((26 - offset) * 7)).strftime('%m/%d/%Y') }
      )
      expect(page).to have_no_link(href: repository_week_path(repository, weeks.first), exact_text: 'Details')
    end

    it 'reaches the oldest week on the second page' do
      visit repository_path(repository, page: 2)

      expect(page).to have_link(href: repository_week_path(repository, weeks.first, page: 2),
                                exact_text: 'Details')
    end

    it 'carries the reader back to the page they came from' do
      visit repository_path(repository, page: 2)
      click_link 'Details'

      expect(page).to have_link('Back to Repository', href: repository_path(repository, page: 2))
    end

    it 'says which weeks are on screen' do
      visit repository_path(repository)

      # Kaminari separates the range with non-breaking spaces.
      expect(page).to have_content('Displaying weeks 1 - 25 of 26 in total', normalize_ws: true)
    end
  end

  describe 'the weeks table with no weeks at all' do
    it 'renders the page without a paginator' do
      visit repository_path(repository)

      expect(page).to have_content('Weeks')
      expect(page).to have_no_css('ul.pagination')
    end
  end

  describe 'the last sync time' do
    before do
      repository.update!(sync_status: 'completed',
                         last_fetched_at: Time.zone.parse('2026-09-01 09:35:27'))
    end

    it 'reads as a local clock time rather than a database timestamp' do
      visit repository_path(repository)

      expect(page).to have_content('Last sync: 09/01/2026 9:35 AM CDT')
      expect(page).to have_no_content('2026-09-01 09:35:27')
    end
  end

  describe 'the flash notice' do
    before do
      allow(RepositorySyncService).to receive(:new).and_return(instance_double(RepositorySyncService, perform: true))

      visit repository_path(repository)
      click_button 'Sync Updates'
    end

    it 'renders once' do
      expect(page).to have_content('Sync job queued')
      expect(page).to have_css('.alert-success', count: 1)
    end

    it 'carries the dismiss attribute Bootstrap 4 binds to' do
      expect(page).to have_css('.alert-success [data-dismiss="alert"]')
    end
  end
end
