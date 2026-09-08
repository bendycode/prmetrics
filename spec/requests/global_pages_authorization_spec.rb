require 'rails_helper'

# The pages that are not scoped to a repository still consult a policy, so a
# rule restricting them has a home and a forgotten authorize call is caught.
RSpec.describe 'Global Pages Authorization' do
  let(:user) { create(:user) }
  let(:contributor) { create(:contributor) }

  before { sign_in user }

  describe 'GET /dashboard' do
    # The not-authorized handler redirects to the dashboard itself, so this
    # only asserts the redirect and never follows it.
    it 'redirects when the dashboard policy denies' do
      denying_policy = instance_double(DashboardPolicy, index?: false)
      allow(DashboardPolicy).to receive(:new).with(user, :dashboard).and_return(denying_policy)

      get dashboard_path

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq('You are not authorized')
    end
  end

  describe 'GET /dashboard?repository_id=:id' do
    let(:repository) { create(:repository) }

    it 'renders the filtered dashboard for a regular user' do
      get dashboard_path(repository_id: repository.id)

      expect(response).to have_http_status(:success)
    end

    it 'redirects home when the repository policy denies the filtered repository' do
      denying_policy = instance_double(RepositoryPolicy, show?: false)
      allow(RepositoryPolicy).to receive(:new).with(user, repository).and_return(denying_policy)

      get dashboard_path(repository_id: repository.id)

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq('You are not authorized')
    end
  end

  describe 'GET /contributors' do
    it 'redirects home when the contributor policy denies the list' do
      denying_policy = instance_double(ContributorPolicy, index?: false)
      allow(ContributorPolicy).to receive(:new).with(user, Contributor).and_return(denying_policy)

      get contributors_path

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq('You are not authorized')
    end
  end

  describe 'GET /contributors/:id' do
    it 'redirects home when the contributor policy denies the record' do
      denying_policy = instance_double(ContributorPolicy, show?: false)
      allow(ContributorPolicy).to receive(:new).with(user, contributor).and_return(denying_policy)

      get contributor_path(contributor)

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq('You are not authorized')
    end
  end

  describe 'GET /account/edit' do
    it 'redirects home when the user policy denies editing the account' do
      denying_policy = instance_double(UserPolicy, edit?: false)
      allow(UserPolicy).to receive(:new).with(user, user).and_return(denying_policy)

      get edit_account_path

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq('You are not authorized')
    end
  end

  describe 'PATCH /account' do
    it 'redirects home when the user policy denies updating the account' do
      denying_policy = instance_double(UserPolicy, update?: false)
      allow(UserPolicy).to receive(:new).with(user, user).and_return(denying_policy)

      patch account_path, params: { user: { email: 'changed@example.com' } }

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq('You are not authorized')
      expect(user.reload.email).not_to eq('changed@example.com')
    end
  end
end
