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

  describe 'POST /users' do
    before { sign_in admin }

    def invite(email, role: 'regular_user', repositories: [])
      post users_path, params: {
        user: { email: email, admin_role_admin: role, granted_repository_ids: [''] + repositories.map(&:id) }
      }
    end

    it 'grants a newly invited regular user the checked repositories' do
      invite('new@example.com', repositories: [first_repository])

      expect(User.find_by!(email: 'new@example.com').granted_repositories).to contain_exactly(first_repository)
    end

    it 'grants a newly invited admin nothing, since admins see every repository' do
      invite('new-admin@example.com', role: 'admin', repositories: [first_repository])

      expect(User.find_by!(email: 'new-admin@example.com').granted_repositories).to be_empty
    end

    it 'creates no grants when the invitation fails' do
      expect { invite('not-an-email', repositories: [first_repository]) }.not_to change(RepositoryGrant, :count)
    end

    it "leaves an existing user's grants unchanged when their email is invited again", :aggregate_failures do
      grant_access(regular_user, first_repository)

      invite(regular_user.email, repositories: [second_repository])

      expect(response.body).to include('has already been taken')
      expect(regular_user.reload.granted_repositories).to contain_exactly(first_repository)
    end

    context 'when the email belongs to a pending invitation' do
      let(:pending_user) { create(:user, :pending, email: 'pending@example.com') }

      before { grant_access(pending_user, first_repository) }

      it 'resends the invitation without changing role or grants', :aggregate_failures do
        invite(pending_user.email, role: 'admin', repositories: [second_repository])

        expect(response).to redirect_to(users_path)
        expect(flash[:notice]).to eq('Invitation resent to pending@example.com; role and repository access unchanged')
        expect(pending_user.reload).to be_regular_user
        expect(pending_user.granted_repositories).to contain_exactly(first_repository)
      end
    end
  end
end
