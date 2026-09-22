require 'rails_helper'

RSpec.describe 'Week page counts' do
  let(:repository) { create(:repository) }
  let!(:week) do
    create(:week, repository: repository, week_number: 202_637, begin_date: Date.new(2026, 9, 14),
                  end_date: Date.new(2026, 9, 20), num_prs_initially_reviewed: nil, num_prs_approved: 0,
                  avg_hrs_to_first_review: nil, avg_hrs_to_approval: nil)
  end

  before { sign_in create(:user, :admin) }

  it 'counts what its lists hold, even on a week no statistics run has touched' do
    monday = Time.zone.parse('2026-09-14 09:00')
    pull_request = create(:pull_request, repository: repository, gh_created_at: monday,
                                         ready_for_review_at: monday)
    create(:review, pull_request: pull_request, state: 'APPROVED', submitted_at: monday + 2.hours)
    pull_request.ensure_weeks_exist_and_update_associations

    get repository_week_path(repository, week)

    expect(response.body).to include('PRs With First Feedback: 1', 'PRs Approved: 1')
  end

  it 'says a wait is unknown rather than showing nothing' do
    get repository_week_path(repository, week)

    expect(response.body).to include('Avg Hours to First Feedback: N/A', 'Avg Hours to Approval: N/A')
  end
end
