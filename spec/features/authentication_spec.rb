require 'rails_helper'

RSpec.describe 'Authentication', type: :feature do
  describe 'user login flows' do
    let(:admin_user) { create(:user, role: :admin) }
    let(:regular_user) { create(:user, role: :regular_user) }

    describe 'admin user login' do
      it 'allows admin to access all areas after login' do
        visit new_user_session_path
        fill_in 'Email', with: admin_user.email
        fill_in 'Password', with: 'password123'
        click_button 'Sign in'

        expect(page).to have_content('Signed in successfully')
        expect(page).to have_content('Administration')
        expect(page).to have_link('Repositories')
        expect(page).to have_link('Users')
      end

      it 'shows repository management controls for admin' do
        # Create a repository so Sync All button appears
        create(:repository)

        sign_in admin_user
        visit repositories_path

        expect(page).to have_button('Add Repository')
        expect(page).to have_button('Sync All')
      end

      it 'allows admin to access user management' do
        sign_in admin_user
        visit users_path

        expect(page).to have_content('Users')
        expect(page).to have_link('Invite User')
      end
    end

    describe 'regular user login' do
      it 'allows regular user to access dashboard after login' do
        visit new_user_session_path
        fill_in 'Email', with: regular_user.email
        fill_in 'Password', with: 'password123'
        click_button 'Sign in'

        expect(page).to have_content('Signed in successfully')
        expect(page).to have_content('Dashboard')
      end

      it 'hides administration section from regular user' do
        sign_in regular_user
        visit root_path

        expect(page).not_to have_content('Administration')
        expect(page).not_to have_link('Users')
      end

      it 'hides repository management controls from regular user' do
        sign_in regular_user
        visit repositories_path

        expect(page).not_to have_button('Add Repository')
        expect(page).not_to have_button('Sync All')
        expect(page).not_to have_button('Delete')
      end

      it 'redirects regular user from user management' do
        sign_in regular_user
        visit users_path

        expect(page).to have_content('You are not authorized')
        expect(current_path).to eq(root_path)
      end

      it 'redirects regular user from new repository form' do
        sign_in regular_user
        visit new_repository_path

        expect(page).to have_content('You are not authorized')
        expect(current_path).to eq(root_path)
      end
    end

    describe 'invitation acceptance' do
      let(:invited_admin) { User.invite!(email: 'admin@example.com', role: :admin) }
      let(:invited_regular) { User.invite!(email: 'regular@example.com', role: :regular_user) }

      it 'allows invited admin to set password and access admin features' do
        visit accept_user_invitation_path(invitation_token: invited_admin.raw_invitation_token)
        fill_in 'Password', with: 'newpassword123'
        fill_in 'Password confirmation', with: 'newpassword123'
        click_button 'Set my password'

        expect(page).to have_content('Your password was set successfully')
        expect(page).to have_content('Administration')
      end

      it 'allows invited regular user to set password and access regular features' do
        visit accept_user_invitation_path(invitation_token: invited_regular.raw_invitation_token)
        fill_in 'Password', with: 'newpassword123'
        fill_in 'Password confirmation', with: 'newpassword123'
        click_button 'Set my password'

        expect(page).to have_content('Your password was set successfully')
        expect(page).not_to have_content('Administration')
      end
    end

    describe 'session management' do
      it 'maintains role-based permissions across page navigation' do
        sign_in regular_user
        visit repositories_path
        visit root_path
        visit repositories_path

        expect(page).not_to have_button('Add Repository')
        expect(page).not_to have_button('Sync All')
      end

      it 'correctly identifies current user role in navigation' do
        sign_in admin_user
        visit root_path

        within('.navbar') do
          expect(page).to have_content(admin_user.email)
        end
      end

      it 'allows user logout' do
        sign_in regular_user
        visit root_path

        # Click the user dropdown to reveal logout option
        find('#userDropdown').click
        # Click the logout link in the dropdown which opens the modal
        find('.dropdown-menu').click_link('Logout')
        # Click the actual logout button in the modal
        find('#logoutModal').click_link('Logout')

        expect(page).to have_content('You need to sign in')
        expect(current_path).to eq(new_user_session_path)
      end
    end

    describe 'unauthorized access attempts' do
      it 'redirects unauthenticated users to login' do
        visit repositories_path

        expect(current_path).to eq(new_user_session_path)
        expect(page).to have_content('You need to sign in')
      end

      it 'blocks direct access to admin routes for regular users' do
        sign_in regular_user
        visit new_repository_path

        expect(page).to have_content('You are not authorized')
        expect(current_path).to eq(root_path)
      end
    end

    describe 'password reset' do
      it 'allows admin user to reset password' do
        visit new_user_session_path
        click_link 'Forgot your password?'
        fill_in 'Email', with: admin_user.email
        click_button 'Send me reset password instructions'

        expect(page).to have_content('You will receive an email')
      end

      it 'allows regular user to reset password' do
        visit new_user_session_path
        click_link 'Forgot your password?'
        fill_in 'Email', with: regular_user.email
        click_button 'Send me reset password instructions'

        expect(page).to have_content('You will receive an email')
      end
    end
  end
end