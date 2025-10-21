require 'rails_helper'

RSpec.describe 'Repositories Authorization' do
  let(:repository) { create(:repository, name: 'test/repo') }

  describe 'Admin user access' do
    let(:admin_user) { create(:user, role: :admin) }

    before do
      sign_in admin_user
    end

    it 'can access sync action' do
      post sync_repository_path(repository)
      expect(response).to redirect_to(repository)
      follow_redirect!
      expect(response.body).to include('Sync job queued')
    end

    it 'can access destroy action' do
      delete repository_path(repository)
      expect(response).to redirect_to(repositories_path)
      expect(Repository.exists?(repository.id)).to be_falsey
    end
  end

  describe 'Regular user access' do
    let(:regular_user) { create(:user, role: :regular_user) }

    before do
      sign_in regular_user
    end

    it 'cannot access sync action' do
      post sync_repository_path(repository)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("You are not authorized")
    end

    it 'cannot access destroy action' do
      delete repository_path(repository)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("You are not authorized")
    end

    it 'can view repository index' do
      get repositories_path
      expect(response).to have_http_status(:success)
    end

    it 'can view repository show' do
      get repository_path(repository)
      expect(response).to have_http_status(:success)
    end
  end

  describe 'Unauthenticated access' do
    it 'redirects to sign in for sync action' do
      post sync_repository_path(repository)
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'redirects to sign in for destroy action' do
      delete repository_path(repository)
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'redirects to sign in for repository index' do
      get repositories_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'redirects to sign in for repository show' do
      get repository_path(repository)
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
