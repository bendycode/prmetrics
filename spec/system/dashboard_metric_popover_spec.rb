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
      expect(page).to have_content('Late Approved PRs')
      expect(page).to have_content('more than 7')
      expect(page).to have_content('Stale Approved PRs')
      expect(page).to have_content('28 or more days')
    end
  end

  it 'opens the popover when the trigger is hovered, no click required' do
    expect(page).to have_css('#prVelocityChart')

    find('button.metric-info-trigger[aria-label*="PR Velocity"]').hover

    expect(page).to have_css('.popover.show', wait: 5)
    within('.popover.show') { expect(page).to have_content('Late Approved PRs') }
  end

  it 'dismisses the popover when the trigger loses both hover and focus' do
    expect(page).to have_css('#prVelocityChart')

    find('button.metric-info-trigger[aria-label*="Review Performance"]').click
    expect(page).to have_css('.popover.show', wait: 5)

    find('h1', text: 'Dashboard').hover
    page.execute_script(
      'document.querySelector(\'button.metric-info-trigger[aria-label*="Review Performance"]\').blur()'
    )

    expect(page).to have_no_css('.popover.show', wait: 5)
  end
end
