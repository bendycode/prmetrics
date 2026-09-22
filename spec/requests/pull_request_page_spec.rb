require 'rails_helper'

RSpec.describe 'Pull request page' do
  let(:ready_at) { Time.zone.parse('2026-09-16 09:00') }
  let(:author) { create(:contributor) }
  let(:pull_request) do
    create(:pull_request, author: author, gh_created_at: ready_at, ready_for_review_at: ready_at)
  end

  before { sign_in create(:user, :admin) }

  it 'reads first feedback from the first review after it was ready, not the earliest review of all' do
    create(:review, pull_request: pull_request, state: 'COMMENTED', submitted_at: ready_at - 2.hours)
    create(:review, pull_request: pull_request, state: 'COMMENTED', submitted_at: ready_at + 3.hours)

    get pull_request_path(pull_request)

    expect(response.body).to include('First feedback at:', 'September 16, 2026 12:00')
  end

  it 'shows when it was approved and how long that took' do
    create(:review, pull_request: pull_request, state: 'APPROVED', submitted_at: ready_at + 5.hours)

    get pull_request_path(pull_request)

    expect(response.body).to include('Approved at:', 'Time to approval:')
  end

  it 'says nobody has approved it when nobody has' do
    get pull_request_path(pull_request)

    expect(response.body).to include('Approved at:').and include('Not yet approved')
  end
end
