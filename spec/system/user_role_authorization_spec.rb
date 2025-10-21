require 'rails_helper'

RSpec.describe 'User Role Authorization', js: true do
  # These specs test the core authorization patterns we'll implement
  # They will fail initially and pass as we build the role system

  describe 'Admin user access' do
    let(:admin_user) { create(:user, role: :admin) }

    before do
      sign_in admin_user
    end

    it 'can access all repository management functions' do
      repository = create(:repository, name: 'test/repo')
      visit repositories_path

      # Admin should see add repository button
      expect(page).to have_button('Add Repository')

      # Admin should see sync and delete buttons for repositories
      expect(page).to have_button('Sync')
      expect(page).to have_link('Delete')
    end

    it 'can access sync and delete actions on repository show page' do
      repository = create(:repository, name: 'test/repo')
      visit repository_path(repository)

      # Admin should see sync controls section
      expect(page).to have_content('Sync Status')
      expect(page).to have_button('Sync Updates')
      expect(page).to have_button('Full Sync')

      # Admin should see delete button
      expect(page).to have_link('Delete Repository')
    end

    it 'can access admin management section' do
      visit root_path

      # Admin should see Administration section in sidebar
      expect(page.html).to include('Administration')
      expect(page).to have_link('Users')

      # Admin should be able to access admin management
      click_link 'Users'
      expect(page).to have_current_path(users_path)
      expect(page).to have_content('User Management')
    end

    it 'can invite new users' do
      visit users_path

      # Admin should see invite button and role selection
      expect(page).to have_link('Invite User')

      click_link 'Invite User'
      expect(page).to have_content('Admin')
      expect(page).to have_field('user_admin_role_admin', type: 'checkbox')
    end

    it 'can access Sidekiq dashboard' do
      visit repositories_path

      # Admin should see Sidekiq link
      expect(page).to have_link('Sidekiq Dashboard')
    end
  end

  describe 'Regular user access' do
    let(:regular_user) { create(:user, role: :regular_user) }

    before do
      sign_in regular_user
    end

    it 'can view repositories but not modify them' do
      repository = create(:repository, name: 'test/repo')
      visit repositories_path

      # Regular user should NOT see add repository button
      expect(page).to have_no_button('Add Repository')

      # Regular user should NOT see sync or delete buttons for repositories
      expect(page).to have_no_button('Sync')
      expect(page).to have_no_link('Delete')
    end

    it 'cannot access sync or delete actions on repository show page' do
      repository = create(:repository, name: 'test/repo')
      visit repository_path(repository)

      # Regular user should NOT see sync controls section
      expect(page).to have_no_content('Sync Status')
      expect(page).to have_no_button('Sync Updates')
      expect(page).to have_no_button('Full Sync')

      # Regular user should NOT see delete button
      expect(page).to have_no_link('Delete Repository')
    end

    it 'is redirected when accessing sync action via direct URL navigation' do
      repository = create(:repository, name: 'test/repo')

      # Attempt to navigate to sync URL directly - should be redirected/blocked
      visit sync_repository_path(repository)
      expect(page).to have_no_content('Sync job queued')
    end

    it 'cannot access admin management section' do
      visit root_path

      # Regular user should NOT see ADMINISTRATION section in sidebar
      expect(page).to have_no_content('Administration')
      expect(page).to have_no_link('Users')
    end

    it 'cannot directly access admin management' do
      # Regular user should be redirected or see 403 when trying direct access
      visit users_path

      # Should be redirected away from admin management
      expect(page).to have_no_content('User Management')
      # Will implement proper 403/redirect behavior with Pundit
    end

    it 'cannot access Sidekiq dashboard' do
      visit repositories_path

      # Regular user should NOT see Sidekiq link
      expect(page).to have_no_link('Sidekiq Dashboard')
    end

    it 'can view all data and metrics' do
      visit root_path

      # Regular user should see dashboard
      expect(page).to have_content('Dashboard')

      # Regular user should see repositories (read-only)
      expect(page).to have_link('Repositories')

      # Regular user should see contributors
      expect(page).to have_link('Contributors')
    end
  end

  describe 'Invitation system with roles' do
    let(:admin_user) { create(:user, role: :admin) }

    before do
      sign_in admin_user
    end

    it 'allows admin to invite regular users' do
      visit new_user_path

      # Should have email field
      expect(page).to have_field('Email')

      # Should have Admin checkbox (unchecked by default for regular users)
      expect(page).to have_field('user_admin_role_admin', type: 'checkbox', checked: false)

      # Fill out form for regular user
      fill_in 'Email', with: 'regular@example.com'
      # Leave Admin checkbox unchecked

      click_button 'Send Invitation'

      # Should create regular user
      expect(page).to have_content('regular@example.com')
      # User should be regular_user role by default
    end

    it 'allows admin to invite admin users' do
      visit new_user_path

      # Fill out form for admin user
      fill_in 'Email', with: 'newadmin@example.com'
      check 'Admin' # Check the admin checkbox

      click_button 'Send Invitation'

      # Should create admin user
      expect(page).to have_content('newadmin@example.com')
      # User should have admin role
    end
  end

  describe 'User dropdown and authentication' do
    it 'shows current user email for both admin and regular users' do
      admin_user = create(:user, role: :admin, email: 'admin@test.com')
      sign_in admin_user

      visit root_path
      expect(page).to have_content('admin@test.com')

      sign_out admin_user

      regular_user = create(:user, role: :regular_user, email: 'user@test.com')
      sign_in regular_user

      visit root_path
      expect(page).to have_content('user@test.com')
    end
  end

  describe 'Authorization edge cases' do
    let(:regular_user) { create(:user, role: :regular_user) }

    before do
      sign_in regular_user
    end

    it 'prevents regular users from accessing admin-only routes via direct URL' do
      # Test various admin-only routes
      admin_only_paths = [
        new_repository_path,
        new_user_path
      ]

      admin_only_paths.each do |path|
        visit path
        # Should be redirected or see authorization error
        expect(page).to have_no_content('Add Repository')
        expect(page).to have_no_content('Invite User')
      end
    end
  end
end