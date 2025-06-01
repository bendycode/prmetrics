require 'rails_helper'

RSpec.describe 'Admin Authentication', type: :system do
  describe 'login flow' do
    let(:admin) { create(:admin, email: 'admin@example.com', password: 'password123') }

    it 'allows admin to log in with valid credentials' do
      visit root_path
      
      # Should redirect to login page
      expect(page).to have_current_path(new_admin_session_path)
      expect(page).to have_content('Admin Login')
      
      # Fill in login form
      fill_in 'Email', with: admin.email
      fill_in 'Password', with: 'password123'
      click_button 'Log in'
      
      # Should be logged in and redirected to root (repositories)
      expect(page).to have_current_path(root_path)
      expect(page).to have_content('Repositories')
    end

    it 'rejects invalid credentials' do
      visit new_admin_session_path
      
      fill_in 'Email', with: 'invalid@example.com'
      fill_in 'Password', with: 'wrongpassword'
      click_button 'Log in'
      
      # Should remain on login page with login form
      expect(page).to have_content('Admin Login')
      expect(page).to have_field('Email')
    end

    it 'redirects unauthenticated users to login' do
      visit repositories_path
      expect(page).to have_current_path(new_admin_session_path)
      
      visit contributors_path
      expect(page).to have_current_path(new_admin_session_path)
    end
  end

  describe 'logout flow' do
    let(:admin) { create(:admin) }

    it 'allows admin to log out' do
      sign_in admin
      visit repositories_path
      
      # Use Devise test helper for logout
      sign_out admin
      
      # Try to access protected page
      visit repositories_path
      expect(page).to have_current_path(new_admin_session_path)
    end
  end

  describe 'password reset flow' do
    let(:admin) { create(:admin, email: 'admin@example.com') }

    it 'sends password reset instructions' do
      visit new_admin_session_path
      click_link 'Forgot your password?'
      
      expect(page).to have_content('Forgot your password?')
      
      fill_in 'Email', with: admin.email
      click_button 'Send me reset password instructions'
      
      # Should redirect back to login page
      expect(page).to have_content('Admin Login')
    end
  end
end