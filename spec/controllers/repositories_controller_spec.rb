require 'rails_helper'

RSpec.describe RepositoriesController do
  let(:user) { create(:user, :admin) }
  let(:repository) { create(:repository) }

  before do
    sign_in user
  end

  describe "GET #index" do
    it "returns http success" do
      get :index
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET #show" do
    it "returns http success" do
      get :show, params: { id: repository.id }
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST #sync" do
    it "queues a sync job" do
      expect {
        post :sync, params: { id: repository.id }
      }.to have_enqueued_job(SyncRepositoryBatchJob).with(repository.name, page: 1, fetch_all: false)
    end

    it "redirects to repository with notice" do
      post :sync, params: { id: repository.id }
      expect(response).to redirect_to(repository)
      expect(flash[:notice]).to eq("Sync job queued for #{repository.name}")
    end

    context "with fetch_all parameter" do
      it "queues a full sync job" do
        expect {
          post :sync, params: { id: repository.id, fetch_all: 'true' }
        }.to have_enqueued_job(SyncRepositoryBatchJob).with(repository.name, page: 1, fetch_all: true)
      end
    end
  end

  describe "GET #new" do
    it "returns http success" do
      get :new
      expect(response).to have_http_status(:success)
    end

    it "assigns a new repository" do
      get :new
      expect(assigns(:repository)).to be_a_new(Repository)
    end
  end

  describe "POST #create" do
    context "with valid params" do
      let(:valid_attributes) { { name: 'rails/rails', url: 'https://github.com/rails/rails' } }

      it "creates a new Repository" do
        expect {
          post :create, params: { repository: valid_attributes }
        }.to change(Repository, :count).by(1)
      end

      it "queues a sync job" do
        expect {
          post :create, params: { repository: valid_attributes }
        }.to have_enqueued_job(SyncRepositoryBatchJob).with('rails/rails', page: 1, fetch_all: true)
      end

      it "redirects to the created repository" do
        post :create, params: { repository: valid_attributes }
        expect(response).to redirect_to(Repository.last)
      end
    end

    context "with invalid params" do
      let(:invalid_attributes) { { name: '', url: '' } }

      it "does not create a new Repository" do
        expect {
          post :create, params: { repository: invalid_attributes }
        }.not_to change(Repository, :count)
      end

      it "returns unprocessable entity status" do
        post :create, params: { repository: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE #destroy" do
    let!(:repository_to_delete) { create(:repository, name: 'test/repo') }
    let!(:pull_request) { create(:pull_request, repository: repository_to_delete) }
    let!(:review) { create(:review, pull_request: pull_request) }

    it "destroys the repository" do
      expect {
        delete :destroy, params: { id: repository_to_delete.id }
      }.to change(Repository, :count).by(-1)
    end

    it "destroys associated pull requests" do
      expect {
        delete :destroy, params: { id: repository_to_delete.id }
      }.to change(PullRequest, :count).by(-1)
    end

    it "destroys associated reviews" do
      expect {
        delete :destroy, params: { id: repository_to_delete.id }
      }.to change(Review, :count).by(-1)
    end

    it "redirects to repositories index with notice" do
      delete :destroy, params: { id: repository_to_delete.id }
      expect(response).to redirect_to(repositories_path)
      expect(flash[:notice]).to eq("Repository 'test/repo' and all associated data have been deleted.")
    end
  end
end
