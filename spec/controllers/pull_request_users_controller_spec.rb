require 'rails_helper'

RSpec.describe PullRequestUsersController do
  let(:user) { create(:user, :admin) }
  let(:pull_request) { create(:pull_request) }
  let(:pull_request_user) { create(:pull_request_user, pull_request: pull_request) }

  before do
    sign_in user
  end

  describe "GET #index" do
    it "returns http success" do
      get :index, params: { pull_request_id: pull_request.id }
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET #show" do
    it "returns http success" do
      get :show, params: { id: pull_request_user.id }
      expect(response).to have_http_status(:success)
    end
  end
end
