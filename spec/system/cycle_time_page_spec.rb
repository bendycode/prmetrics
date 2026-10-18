require 'rails_helper'

RSpec.describe 'Cycle Time page' do
  let(:user) { create(:user) }
  let(:repository) { create(:repository, name: 'granted/visible') }
  let(:tracker) { create(:tracker, :covering_source, source_repository: repository, key_prefix: 'PRM') }
  let(:day0) { Time.zone.parse('2026-09-01 10:00') }

  def finished(number, title, days, started_after: 0, **attributes)
    create(:story, tracker: tracker, external_id: number.to_s, key: "PRM-#{number}", title: title,
                   url: "https://github.com/granted/visible/issues/#{number}", state: 'closed',
                   committed_at: day0, committed_source: :opened,
                   started_at: started_after && (day0 + (started_after * 24).hours),
                   started_source: started_after && :assigned,
                   done_at: day0 + (days * 24).hours, **attributes)
  end

  before do
    grant_access(user, repository)
    sign_in user
  end

  describe 'the title' do
    it 'names every repository the tracker covers' do
      grant_access(user, create(:repository, name: 'granted/second', tracker: tracker))

      visit tracker_path(tracker)

      expect(page).to have_css('h1', exact_text: 'Cycle Time: granted/second and granted/visible')
    end

    it 'leaves out a covered repository the user was not granted' do
      create(:repository, name: 'ungranted/covered', tracker: tracker)

      visit tracker_path(tracker)

      expect(page).to have_css('h1', exact_text: 'Cycle Time: granted/visible')
    end
  end

  context 'with finished issues' do
    before do
      finished(1, 'Expire stale sessions', 2)
      finished(2, 'Retry webhook deliveries', 4, started_after: 1, started_source: :commit_referenced)
      finished(3, 'Keep blank rows', 6, started_after: nil)
      create(:story, tracker: tracker, external_id: '4', key: 'PRM-4', title: 'Still open')
    end

    def coverage_line
      page.find('p.text-muted').text
    end

    def row(key)
      page.find('tbody tr', text: key).all('td').map(&:text)
    end

    it 'shows the committed clock: its figures, its coverage, and every finished issue', :aggregate_failures do
      visit tracker_path(tracker)

      expect(page).to have_css('[data-clock-chosen]', text: 'Committed to done')
      expect(page).to have_text('Median 4 days').and have_text('85th percentile 6 days')
      expect(coverage_line).to eq('3 issues measured from Opened, 0 from a fallback.')
      expect(page.all('tbody tr').map { |row| row.first('td').text })
        .to eq(%w[PRM-1 PRM-2 PRM-3])
    end

    it 'shows each issue\'s dates, the event each came from, and its cycle time' do
      visit tracker_path(tracker)

      expect(row('PRM-2')).to eq(['PRM-2', 'Retry webhook deliveries', '09/01/2026 (Opened)', '09/02/2026 (Commit)',
                                  '09/05/2026', '4 days'])
      expect(row('PRM-3')).to eq(['PRM-3', 'Keep blank rows', '09/01/2026 (Opened)', 'None', '09/07/2026', '6 days'])
    end

    it 'switches to the started clock, leaving out the issue that never started', :aggregate_failures do
      visit tracker_path(tracker)
      click_link 'Started to done'

      expect(page).to have_css('[data-clock-chosen]', text: 'Started to done')
      expect(page).to have_text('Median 2 days').and have_text('85th percentile 3 days')
      expect(coverage_line).to eq('1 issue measured from Assigned, 1 from a fallback. 1 had no start and is left out.')
      expect(page.all('tbody tr').map { |row| row.first('td').text }).to eq(%w[PRM-1 PRM-2])
    end

    it 'links each issue to GitHub' do
      visit tracker_path(tracker)

      expect(page).to have_link('Expire stale sessions', href: 'https://github.com/granted/visible/issues/1')
    end
  end

  it 'says how many issues had no start when several did' do
    finished(6, 'Started', 1)
    finished(7, 'Never started', 2, started_after: nil)
    finished(8, 'Also never started', 3, started_after: nil)

    visit tracker_path(tracker, clock: 'started')

    expect(page.find('p.text-muted').text)
      .to eq('1 issue measured from Assigned, 0 from a fallback. 2 had no start and are left out.')
  end

  # A stored URL could hold anything; only one on GitHub becomes a link
  it 'shows a title without a link when its URL is not on GitHub' do
    finished(5, 'Odd link', 1, url: 'javascript:alert(1)')

    visit tracker_path(tracker)

    expect(page).to have_text('Odd link')
    expect(page).to have_no_link('Odd link')
  end

  it 'says when no issue has finished yet' do
    create(:story, tracker: tracker, title: 'Still open')

    visit tracker_path(tracker)

    expect(page).to have_text('No finished issues yet.')
    expect(page).to have_no_table
  end
end
