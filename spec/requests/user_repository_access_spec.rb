require 'rails_helper'

RSpec.describe 'User repository access management' do
  let(:admin) { create(:user, :admin) }
  let(:regular_user) { create(:user) }
  let(:first_repository) { create(:repository, name: 'owner/first') }
  let(:second_repository) { create(:repository, name: 'owner/second') }

  def expect_refused
    expect(response).to redirect_to(root_path)
    expect(flash[:alert]).to eq('You are not authorized')
  end

  describe 'GET /users/:user_id/repository_access/edit' do
    it "shows an admin every repository with the user's grants checked", :aggregate_failures do
      grant_access(regular_user, first_repository)
      second_repository
      sign_in admin

      get edit_user_repository_access_path(regular_user)

      expect(response).to have_http_status(:success)
      page = Capybara.string(response.body)
      expect(page).to have_checked_field('owner/first')
      expect(page).to have_unchecked_field('owner/second')
    end

    it 'refuses an admin opening repository access for another admin', :aggregate_failures do
      sign_in admin

      get edit_user_repository_access_path(create(:user, :admin))

      expect_refused
    end

    it 'refuses a regular user opening their own repository access', :aggregate_failures do
      sign_in regular_user

      get edit_user_repository_access_path(regular_user)

      expect_refused
    end
  end

  describe 'PATCH /users/:user_id/repository_access' do
    def save_access(user, repository_ids)
      patch user_repository_access_path(user), params: { user: { granted_repository_ids: [''] + repository_ids } }
    end

    it "replaces a regular user's grants when an admin saves them", :aggregate_failures do
      grant_access(regular_user, first_repository)
      sign_in admin

      save_access(regular_user, [second_repository.id])

      expect(response).to redirect_to(users_path)
      expect(flash[:notice]).to eq("Repository access updated for #{regular_user.email}.")
      expect(regular_user.reload.granted_repositories).to contain_exactly(second_repository)
    end

    it 'clears every grant when an admin unchecks them all' do
      grant_access(regular_user, first_repository, second_repository)
      sign_in admin

      save_access(regular_user, [])

      expect(regular_user.reload.granted_repositories).to be_empty
    end

    it 'ignores a repository that no longer exists and a repeated id', :aggregate_failures do
      sign_in admin
      deleted_id = create(:repository).tap(&:destroy).id

      save_access(regular_user, [first_repository.id, first_repository.id, deleted_id])

      expect(response).to redirect_to(users_path)
      expect(regular_user.reload.granted_repositories).to contain_exactly(first_repository)
    end

    it 'refuses granting repositories to an admin', :aggregate_failures do
      other_admin = create(:user, :admin)
      sign_in admin

      save_access(other_admin, [first_repository.id])

      expect_refused
      expect(other_admin.reload.granted_repositories).to be_empty
    end

    it 'refuses a regular user granting themselves repositories', :aggregate_failures do
      sign_in regular_user

      save_access(regular_user, [first_repository.id])

      expect_refused
      expect(regular_user.reload.granted_repositories).to be_empty
    end
  end

  describe 'POST /users' do
    before { sign_in admin }

    def invite(email, admin: false, repositories: [])
      post users_path, params: {
        user: { email: email, admin_role_admin: admin ? 'admin' : 'regular_user',
                granted_repository_ids: [''] + repositories.map(&:id) }
      }
    end

    it 'grants a newly invited regular user the checked repositories', :aggregate_failures do
      invite('new@example.com', repositories: [first_repository])

      expect(flash[:notice]).to eq('Invitation sent to new@example.com.')
      expect(User.find_by!(email: 'new@example.com').granted_repositories).to contain_exactly(first_repository)
    end

    it 'grants a newly invited admin nothing' do
      invite('new-admin@example.com', admin: true, repositories: [first_repository])

      expect(User.find_by!(email: 'new-admin@example.com').granted_repositories).to be_empty
    end

    it 'invites the user and ignores a checked repository that no longer exists', :aggregate_failures do
      deleted = create(:repository).tap(&:destroy)

      invite('new@example.com', repositories: [first_repository, deleted])

      expect(response).to redirect_to(users_path)
      expect(User.find_by!(email: 'new@example.com').granted_repositories).to contain_exactly(first_repository)
    end

    it 're-renders the invitation form with its repository choices when the email is invalid', :aggregate_failures do
      second_repository

      invite('not-an-email', repositories: [first_repository])

      expect(response).to have_http_status(:unprocessable_content)
      page = Capybara.string(response.body)
      expect(page).to have_content('Email is invalid')
      expect(page).to have_checked_field('owner/first')
      expect(page).to have_unchecked_field('owner/second')
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
        expect { invite(' Pending@Example.com ', admin: true, repositories: [second_repository]) }
          .to change(ActionMailer::Base.deliveries, :count).by(1)

        expect(response).to redirect_to(users_path)
        expect(flash[:notice]).to eq('Invitation resent to pending@example.com. Role and repository access are unchanged.')
        expect(pending_user.reload).to be_regular_user
        expect(pending_user.granted_repositories).to contain_exactly(first_repository)
      end
    end
  end
end
