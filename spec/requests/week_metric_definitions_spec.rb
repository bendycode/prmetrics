require 'rails_helper'

RSpec.describe 'Week show metric definitions' do
  let(:user) { create(:user, role: :admin) }
  let(:repository) { create(:repository, name: 'test/week-show') }
  let(:week) do
    create(:week, repository: repository, begin_date: 1.week.ago,
                  num_prs_late: 2, num_prs_stale: 1)
  end

  before { sign_in user }

  it 'renders an info icon next to the Late/Stale PR statistics' do
    get repository_week_path(repository, week)

    expect(response.body).to include('data-toggle="popover"')
    expect(response.body).to match(/aria-label="[^"]*Week Statistics[^"]*"/)
  end

  it 'embeds the Late and Stale threshold definitions in popover content' do
    get repository_week_path(repository, week)

    expect(response.body).to match(/Late PRs.*more than 7.*fewer than 28/m)
    expect(response.body).to match(/Stale PRs.*28 or more days/m)
  end
end
