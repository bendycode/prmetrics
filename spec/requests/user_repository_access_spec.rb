require 'rails_helper'

RSpec.describe 'User repository access management' do
  let(:admin) { create(:user, :admin) }
  let(:regular_user) { create(:user) }
  let(:first_repository) { create(:repository, name: 'owner/first') }
  let(:second_repository) { create(:repository, name: 'owner/second') }

  describe 'PATCH /users/:id' do
    it 'replaces a regular user\'s grants when an admin saves them' do
      grant_access(regular_user, first_repository)
      sign_in admin

      patch user_path(regular_user), params: { user: { granted_repository_ids: ['', second_repository.id] } }

      expect(regular_user.reload.granted_repositories).to contain_exactly(second_repository)
    end

    it 'clears every grant when an admin unchecks them all' do
      grant_access(regular_user, first_repository, second_repository)
      sign_in admin

      patch user_path(regular_user), params: { user: { granted_repository_ids: [''] } }

      expect(regular_user.reload.granted_repositories).to be_empty
    end

    it 'refuses granting repositories to an admin', :aggregate_failures do
      other_admin = create(:user, :admin)
      sign_in admin

      patch user_path(other_admin), params: { user: { granted_repository_ids: [first_repository.id] } }

      expect(response).to redirect_to(root_path)
      expect(other_admin.reload.granted_repositories).to be_empty
    end

    it 'refuses a regular user granting themselves repositories', :aggregate_failures do
      sign_in regular_user

      patch user_path(regular_user), params: { user: { granted_repository_ids: [first_repository.id] } }

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq('You are not authorized')
      expect(regular_user.reload.granted_repositories).to be_empty
    end
  end

  describe 'GET /users/:id/edit' do
    it 'refuses a regular user' do
      sign_in regular_user

      get edit_user_path(regular_user)

      expect(response).to redirect_to(root_path)
    end
  end
end
