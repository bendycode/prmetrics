require 'rails_helper'

RSpec.describe 'Dashboard metric popovers', :js do
  let(:user) { create(:user, :admin) }
  let(:repository) { create(:repository, name: 'test/popover') }

  before do
    create(:week,
           repository: repository,
           begin_date: 1.week.ago,
           num_prs_started: 4,
           num_prs_merged: 3,
           num_prs_cancelled: 1,
           num_prs_late: 2,
           num_prs_stale: 1)

    sign_in user
    visit dashboard_path
  end

  it 'opens a popover with the Late/Stale definitions when the PR Velocity info icon is clicked' do
    expect(page).to have_css('#prVelocityChart')

    pr_velocity_trigger = find('button.metric-info-trigger[aria-label*="PR Velocity"]')
    pr_velocity_trigger.click

    expect(page).to have_css('.popover.show', wait: 5)
    within('.popover.show') do
      expect(page).to have_content('Late PRs')
      expect(page).to have_content('more than 7')
      expect(page).to have_content('Stale PRs')
      expect(page).to have_content('28 or more days')
    end
  end

  it 'dismisses the popover when the trigger loses focus' do
    expect(page).to have_css('#prVelocityChart')

    find('button.metric-info-trigger[aria-label*="Review Performance"]').click
    expect(page).to have_css('.popover.show', wait: 5)

    page.execute_script(
      'document.querySelector(\'button.metric-info-trigger[aria-label*="Review Performance"]\').blur()'
    )

    expect(page).to have_no_css('.popover.show', wait: 5)
  end
end
