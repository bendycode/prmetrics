require 'rails_helper'

RSpec.describe 'Cycle Time scatterplot', :js do
  let(:user) { create(:user) }
  let(:repository) { create(:repository) }
  let(:tracker) { create(:tracker, :covering_source, source_repository: repository, key_prefix: 'PRM') }
  let(:day0) { Time.zone.parse('2026-09-01 10:00') }
  let!(:first) { finished(1, done_after: 2, started_after: 1) }
  let!(:second) { finished(2, done_after: 6, started_after: 2) }

  def finished(number, done_after:, started_after:)
    create(:story, tracker: tracker, external_id: number.to_s, key: "PRM-#{number}", state: 'closed',
                   committed_at: day0, committed_source: :opened,
                   started_at: day0 + (started_after * 24).hours, started_source: :assigned,
                   done_at: day0 + (done_after * 24).hours)
  end

  # The chart is drawn once the page has loaded
  def plotted
    expect(page).to have_css('canvas#cycleTimeChart[data-drawn]')
    page.evaluate_script(<<~JS)
      Chart.getChart('cycleTimeChart').data.datasets[0].data.map((point) => [point.x, point.y, point.key])
    JS
  end

  def milliseconds(time)
    (time.to_f * 1000).round
  end

  before do
    grant_access(user, repository)
    sign_in user
  end

  it 'plots each finished issue\'s cycle time in days by the date it was done' do
    visit tracker_path(tracker)

    expect(page).to have_css('canvas#cycleTimeChart')
    expect(plotted).to eq([[milliseconds(first.done_at), 2, 'PRM-1'], [milliseconds(second.done_at), 6, 'PRM-2']])
  end

  it 'labels the time axis with dates in the app\'s zone' do
    visit tracker_path(tracker)
    expect(page).to have_css('canvas#cycleTimeChart[data-drawn]')

    label = page.evaluate_script(
      "Chart.getChart('cycleTimeChart').options.scales.x.ticks.callback(#{milliseconds(first.done_at)})"
    )
    expect(label).to eq('9/3/2026')
  end

  it 'plots the started clock after switching to it' do
    visit tracker_path(tracker)
    click_link 'Started to done'

    expect(page).to have_css('[data-clock-chosen]', text: 'Started to done')
    expect(plotted).to eq([[milliseconds(first.done_at), 1, 'PRM-1'], [milliseconds(second.done_at), 4, 'PRM-2']])
  end
end
