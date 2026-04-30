require 'rails_helper'

RSpec.describe 'Dashboard metric definitions' do
  let(:user) { create(:user, role: :admin) }

  before do
    repository = create(:repository, name: 'test/metrics')
    create(:week, repository: repository, begin_date: 1.week.ago,
                  num_prs_started: 4, num_prs_merged: 3, num_prs_cancelled: 1)
    sign_in user
  end

  it 'renders an info icon for the PR Velocity Trends chart' do
    get dashboard_path

    expect(response.body).to include('data-toggle="popover"')
    expect(response.body).to match(/aria-label="[^"]*PR Velocity[^"]*"/)
  end

  it 'embeds the Late PRs definition with the 7-day threshold in popover content' do
    get dashboard_path

    expect(response.body).to include('Late PRs')
    expect(response.body).to match(/Late PRs.*more than 7.*fewer than 28/m)
  end

  it 'embeds the Stale PRs definition with the 28-day threshold in popover content' do
    get dashboard_path

    expect(response.body).to include('Stale PRs')
    expect(response.body).to match(/Stale PRs.*28 or more days/m)
  end

  it 'renders an info icon for the Review Performance chart' do
    get dashboard_path

    expect(response.body).to match(/aria-label="[^"]*Review Performance[^"]*"/)
    expect(response.body).to include('Hours to First Review')
    expect(response.body).to include('Hours to Merge')
  end

  it 'renders an info icon for the Repository Performance Comparison chart' do
    get dashboard_path

    expect(response.body).to match(/aria-label="[^"]*Repository Performance[^"]*"/)
    expect(response.body).to include('Merge Rate')
  end
end
