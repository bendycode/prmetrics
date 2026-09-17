require 'rails_helper'

RSpec.describe "Managing a user's repository access" do
  let(:admin) { create(:user, :admin) }
  let(:member) { create(:user, email: 'member@example.com') }
  let(:first_repository) { create(:repository, name: 'owner/first') }
  let(:second_repository) { create(:repository, name: 'owner/second') }

  it "shows an admin a regular user's current grants from the user list", :aggregate_failures do
    grant_access(member, first_repository)
    second_repository

    sign_in admin
    visit users_path
    within('tr', text: member.email) { click_link 'Repository Access' }

    expect(page).to have_checked_field('owner/first')
    expect(page).to have_unchecked_field('owner/second')
  end

  it 'shows a user only the repositories an admin left checked', :aggregate_failures do
    grant_access(member, first_repository)
    second_repository

    sign_in admin
    visit edit_user_repository_access_path(member)
    uncheck 'owner/first'
    check 'owner/second'
    click_button 'Save Access'
    expect(page).to have_content("Repository access updated for #{member.email}.")

    sign_in member
    visit repositories_path

    expect(page).to have_content('owner/second')
    expect(page).to have_no_content('owner/first')
  end

  it 'shows a user the no-access message after an admin revokes every repository' do
    grant_access(member, first_repository, second_repository)

    sign_in admin
    visit edit_user_repository_access_path(member)
    uncheck 'owner/first'
    uncheck 'owner/second'
    click_button 'Save Access'
    expect(page).to have_content("Repository access updated for #{member.email}.")

    sign_in member
    visit repositories_path

    expect(page).to have_content('No repositories have been shared with you yet')
  end

  it "offers the repository access link only on a regular user's row", :aggregate_failures do
    member
    other_admin = create(:user, :admin, email: 'other-admin@example.com')

    sign_in admin
    visit users_path

    within('tr', text: member.email) { expect(page).to have_link('Repository Access') }
    within('tr', text: other_admin.email) { expect(page).to have_no_link('Repository Access') }
  end

  it 'lets an admin choose repositories while inviting a regular user', :aggregate_failures do
    first_repository
    second_repository

    sign_in admin
    visit new_user_path
    fill_in 'Email', with: 'invitee@example.com'
    check 'owner/second'
    click_button 'Send Invitation'
    expect(page).to have_content('Invitation sent to invitee@example.com.')

    within('tr', text: 'invitee@example.com') { click_link 'Repository Access' }

    expect(page).to have_checked_field('owner/second')
    expect(page).to have_unchecked_field('owner/first')
  end
end
