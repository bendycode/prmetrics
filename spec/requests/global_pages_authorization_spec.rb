require 'rails_helper'

# The pages whose URLs sit outside a repository still consult a policy, so a
# rule restricting them has a home and a forgotten authorize call is caught.
RSpec.describe 'Global Pages Authorization' do
  let(:user) { create(:user) }

  before { sign_in user }

  describe 'GET /dashboard' do
    # The not-authorized handler redirects to the dashboard itself, so this
    # only asserts the redirect and never follows it.
    it 'redirects when the dashboard policy denies' do
      deny_policy(DashboardPolicy, :index?, user, on: :dashboard)

      get dashboard_path

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq('You are not authorized')
    end
  end

  describe 'GET /dashboard?repository_id=:id' do
    let(:repository) { create(:repository) }

    before { grant_access(user, repository) }

    it 'renders the filtered dashboard for a regular user' do
      get dashboard_path(repository_id: repository.id)

      expect(response).to have_http_status(:success)
    end

    it 'renders the unfiltered dashboard when repository_id is not a single id' do
      get dashboard_path(repository_id: [repository.id, create(:repository).id])

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include("for #{repository.name}")
    end

    it 'renders the unfiltered dashboard for an ungranted repository, as for a missing one', :aggregate_failures do
      hidden_repository = create(:repository)

      get dashboard_path(repository_id: hidden_repository.id)

      expect(response).to have_http_status(:success)
      expect(flash[:alert]).to be_nil
      expect(response.body).not_to include("for #{hidden_repository.name}")
    end
  end

  describe 'GET /contributors' do
    it 'redirects home when the contributor policy denies the list' do
      deny_policy(ContributorPolicy, :index?, user, on: Contributor)

      get contributors_path

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq('You are not authorized')
    end
  end

  describe 'GET /contributors/:id' do
    let(:granted_repository) { create(:repository) }

    before { grant_access(user, granted_repository) }

    it 'answers not found for a contributor with no activity in a granted repository' do
      hidden_contributor = create(:pull_request, repository: create(:repository)).author

      get contributor_path(hidden_contributor)

      expect(response).to have_http_status(:not_found)
    end

    it 'lists only pull requests from granted repositories', :aggregate_failures do
      participant = create(:contributor)
      create(:pull_request_user, user: participant,
                                 pull_request: create(:pull_request, repository: granted_repository,
                                                                     title: 'Granted work'))
      create(:pull_request_user, user: participant,
                                 pull_request: create(:pull_request, repository: create(:repository),
                                                                     title: 'Hidden work'))

      get contributor_path(participant)

      expect(response.body).to include('Granted work')
      expect(response.body).not_to include('Hidden work')
    end
  end

  describe 'GET /account/edit' do
    it 'renders for a regular user editing their own account' do
      get edit_account_path

      expect(response).to have_http_status(:success)
    end

    it 'redirects home when the user policy denies editing the account' do
      deny_policy(UserPolicy, :edit?, user, on: user)

      get edit_account_path

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq('You are not authorized')
    end
  end

  describe 'PATCH /account' do
    it 'saves for a regular user editing their own account' do
      patch account_path, params: { user: { email: 'changed@example.com' } }

      expect(user.reload.email).to eq('changed@example.com')
    end

    it 'redirects home when the user policy denies updating the account', :aggregate_failures do
      deny_policy(UserPolicy, :update?, user, on: user)

      patch account_path, params: { user: { email: 'changed@example.com' } }

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq('You are not authorized')
      expect(user.reload.email).not_to eq('changed@example.com')
    end
  end
end
