require 'rails_helper'

RSpec.describe 'Managing a user\'s repository access' do
  let(:admin) { create(:user, :admin) }
  let(:member) { create(:user, email: 'member@example.com') }
  let!(:first_repository) { create(:repository, name: 'owner/first') }
  let!(:second_repository) { create(:repository, name: 'owner/second') }

  it 'lets an admin grant and revoke repositories, and the user sees exactly the granted ones' do
    grant_access(member, first_repository)

    sign_in admin
    visit users_path
    within('tr', text: member.email) { click_link 'Repository access' }

    expect(page).to have_checked_field('owner/first')
    expect(page).to have_unchecked_field('owner/second')

    uncheck 'owner/first'
    check 'owner/second'
    click_button 'Save access'

    expect(page).to have_content('Repository access updated for member@example.com')

    sign_in member
    visit repositories_path

    expect(page).to have_content('owner/second')
    expect(page).to have_no_content('owner/first')
  end

  it 'lets an admin revoke every repository' do
    grant_access(member, first_repository, second_repository)

    sign_in admin
    visit edit_user_path(member)
    uncheck 'owner/first'
    uncheck 'owner/second'
    click_button 'Save access'

    sign_in member
    visit repositories_path

    expect(page).to have_content('No repositories have been shared with you yet')
  end

  it 'offers no repository access link for an admin' do
    other_admin = create(:user, :admin, email: 'other-admin@example.com')

    sign_in admin
    visit users_path

    within('tr', text: other_admin.email) { expect(page).to have_no_link('Repository access') }
  end

  it 'lets an admin choose repositories while inviting a regular user' do
    sign_in admin
    visit new_user_path
    fill_in 'Email', with: 'invitee@example.com'
    check 'owner/second'
    click_button 'Send Invitation'

    expect(page).to have_content('Invitation sent to invitee@example.com')
    expect(User.find_by!(email: 'invitee@example.com').granted_repositories).to contain_exactly(second_repository)
  end
end
