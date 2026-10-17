require 'rails_helper'

RSpec.describe 'Cycle Time page' do
  include_context 'with a regular user granted one repository'

  let(:tracker) { create(:tracker, :covering_source, source_repository: granted_repository) }

  def chosen_clock
    Capybara.string(response.body).find('[data-clock-chosen]').text.strip
  end

  it 'shows the committed clock by default' do
    get tracker_path(tracker)

    expect(response).to have_http_status(:success)
    expect(chosen_clock).to eq('Committed to done')
  end

  it 'shows the started clock when asked' do
    get tracker_path(tracker, clock: 'started')

    expect(chosen_clock).to eq('Started to done')
  end

  # Only the two clocks' names choose one, so an Array, a Hash, or another
  # word reaches neither the report nor the page.
  [{ clock: 'deleted' }, { clock: ['started'] }, { clock: { started: '1' } }].each do |params|
    it "shows the committed clock for #{params.inspect}" do
      get tracker_path(tracker, params)

      expect(response).to have_http_status(:success)
      expect(chosen_clock).to eq('Committed to done')
    end
  end

  # A tracker whose issues are never assigned, committed to, or linked
  it 'shows the coverage line, not an empty state, when issues finished but none started' do
    day0 = Time.zone.parse('2026-09-01 10:00')
    create(:story, tracker: tracker, state: 'closed', committed_at: day0, committed_source: :opened,
                   done_at: day0 + 48.hours)

    get tracker_path(tracker, clock: 'started')

    expect(response.body).not_to include('No finished issues yet.')
    expect(response.body).to include('1 had no start and is left out.')
  end

  it 'is not found for a tracker covering only repositories the user was not granted' do
    get tracker_path(create(:tracker, :covering_source))

    expect(response).to have_http_status(:not_found)
  end

  it 'sends a signed-out visitor to sign in' do
    sign_out user

    get tracker_path(tracker)

    expect(response).to redirect_to(new_user_session_path)
  end
end
