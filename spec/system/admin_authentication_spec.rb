require 'rails_helper'

RSpec.describe 'Admin Authentication' do
  describe 'login flow' do
    let(:admin) { create(:user, :admin, email: 'admin@example.com', password: 'password123') }

    it 'allows admin to log in with valid credentials' do
      visit root_path

      # Should redirect to login page
      expect(page).to have_current_path(new_user_session_path)
      expect(page).to have_content('Sign In')

      # Fill in login form
      fill_in 'Email', with: admin.email
      fill_in 'Password', with: 'password123'
      click_button 'Sign in'

      # Should be logged in and redirected to root (repositories)
      expect(page).to have_current_path(root_path)
      expect(page).to have_content('Repositories')
    end

    it 'rejects invalid credentials' do
      visit new_user_session_path

      fill_in 'Email', with: 'invalid@example.com'
      fill_in 'Password', with: 'wrongpassword'
      click_button 'Sign in'

      # Should remain on login page with login form
      expect(page).to have_content('Sign In')
      expect(page).to have_field('Email')
    end

    it 'redirects unauthenticated users to login' do
      visit repositories_path
      expect(page).to have_current_path(new_user_session_path)

      visit contributors_path
      expect(page).to have_current_path(new_user_session_path)
    end
  end

  describe 'logout flow' do
    let(:admin) { create(:user, :admin) }

    it 'ends the session from the Logout link in the user menu', :js do
      sign_in admin
      visit repositories_path

      find_by_id('userDropdown').click
      within('[aria-labelledby="userDropdown"]') { click_link 'Logout' }
      within('#logoutModal') { click_link 'Logout' }
      expect(page).to have_current_path(new_user_session_path)

      visit repositories_path
      expect(page).to have_current_path(new_user_session_path)
    end
  end

  describe 'password reset flow' do
    let(:admin) { create(:user, :admin, email: 'admin@example.com') }

    it 'confirms that reset instructions were sent' do
      visit new_user_session_path
      click_link 'Forgot your password?'

      expect(page).to have_content('Forgot your password?')

      fill_in 'Email', with: admin.email
      click_button 'Send me password reset instructions'

      expect(page).to have_content(I18n.t('devise.passwords.send_instructions'))
    end
  end
end
