require 'rails_helper'

RSpec.describe PullRequestsController do
  let(:user) { create(:user, :admin) }
  let(:repository) { create(:repository) }
  let(:pull_request) { create(:pull_request, repository: repository) }

  before do
    sign_in user
  end


  describe "GET #index" do
    it "returns http success" do
      get :index, params: { repository_id: repository.id }
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET #show" do
    it "returns http success" do
      get :show, params: { id: pull_request.id }
      expect(response).to have_http_status(:success)
    end
  end
end
