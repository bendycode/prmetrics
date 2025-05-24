require 'rails_helper'

RSpec.describe RepositoriesController, type: :controller do
  let(:admin) { create(:admin) }
  let(:repository) { create(:repository) }
  
  before do
    sign_in admin
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
      }.to have_enqueued_job(SyncRepositoryJob).with(repository.name, fetch_all: false)
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
        }.to have_enqueued_job(SyncRepositoryJob).with(repository.name, fetch_all: true)
      end
    end
  end
end
