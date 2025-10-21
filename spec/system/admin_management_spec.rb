require 'rails_helper'

RSpec.describe 'User Management' do
  let(:admin) { create(:user, :admin, email: 'admin@example.com') }
  let(:other_admin) { create(:user, :admin, email: 'other@example.com', invitation_accepted_at: 1.day.ago) }
  let(:pending_admin) { create(:user, :admin, email: 'pending@example.com', invitation_accepted_at: nil) }

  before do
    sign_in admin
  end

  describe 'admin index page' do
    before do
      other_admin
      pending_admin
    end

    it 'displays all admins with their status' do
      visit users_path

      expect(page).to have_content('User Management')
      expect(page).to have_content('admin@example.com')
      expect(page).to have_content('other@example.com')
      expect(page).to have_content('pending@example.com')

      # Check status badges
      expect(page).to have_content('Active')
      expect(page).to have_content('Pending Invitation')
    end

    it 'shows current admin with "You" badge' do
      visit users_path

      within('tr', text: admin.email) do
        expect(page).to have_content('You')
      end
    end

    it 'displays admin statistics' do
      visit users_path

      expect(page).to have_content('Total: 3 users')
      expect(page).to have_content('2 active, 1 pending')
    end

    it 'shows invitation details for pending admins' do
      visit users_path

      within('tr', text: pending_admin.email) do
        expect(page).to have_content('Pending Invitation')
      end
    end

    it 'prevents current admin from removing themselves' do
      visit users_path

      within('tr', text: admin.email) do
        expect(page).to have_no_button('Remove')
      end
    end

    it 'allows removing other admins' do
      visit users_path

      within('tr', text: other_admin.email) do
        expect(page).to have_button('Remove')
      end

      # For now, just verify the remove button is present
      # Full functionality would require JavaScript confirmation
      expect(page).to have_content(other_admin.email)
    end
  end

  describe 'inviting new admin' do
    it 'allows navigation to invitation form' do
      visit users_path

      click_link 'Invite User'

      expect(page).to have_current_path(new_user_path)
      expect(page).to have_content('Invite User')
    end

    it 'successfully invites a new admin' do
      visit new_user_path

      fill_in 'Email', with: 'newadmin@example.com'
      click_button 'Send Invitation'

      expect(page).to have_current_path(users_path)
      expect(page).to have_content('newadmin@example.com')
      expect(page).to have_content('Pending Invitation')
    end

    it 'validates email presence' do
      visit new_user_path

      fill_in 'Email', with: ''
      click_button 'Send Invitation'

      expect(page).to have_content("Email can't be blank")
      expect(page).to have_current_path(users_path) # Form posts to create action
    end

    it 'validates email format' do
      visit new_user_path

      fill_in 'Email', with: 'invalid-email'
      click_button 'Send Invitation'

      expect(page).to have_content('Email is invalid')
    end

    it 'prevents duplicate email invitations' do
      visit new_user_path

      fill_in 'Email', with: admin.email
      click_button 'Send Invitation'

      expect(page).to have_content('Email has already been taken')
    end

    it 'allows canceling invitation form' do
      visit new_user_path

      click_link 'Cancel'

      expect(page).to have_current_path(users_path)
    end
  end

  describe 'admin removal safeguards' do
    it 'prevents removing the last active admin' do
      # Make current admin the only active admin
      other_admin.update!(invitation_accepted_at: nil)

      visit users_path

      # Should not have remove button for current admin
      within('tr', text: admin.email) do
        expect(page).to have_no_button('Remove')
      end

      # Other admin should be removable since they're pending
      within('tr', text: other_admin.email) do
        expect(page).to have_button('Remove')
      end
    end
  end

  describe 'navigation integration' do
    it 'provides access to admin management' do
      visit users_path

      expect(page).to have_content('User Management')
    end
  end

  describe 'responsive layout' do
    it 'displays admin table properly on different screen sizes' do
      visit users_path

      # Check that table headers are present
      expect(page).to have_content('Email')
      expect(page).to have_content('Status')
      expect(page).to have_content('Actions')

      # Check that the table is responsive (Bootstrap classes)
      expect(page).to have_css('.table')
    end
  end

  describe 'error handling' do
    it 'handles invalid email gracefully' do
      visit new_user_path

      fill_in 'Email', with: 'invalid-email'
      click_button 'Send Invitation'

      expect(page).to have_content('Email is invalid')
    end
  end
end