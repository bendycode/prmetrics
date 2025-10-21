require 'rails_helper'

RSpec.describe ContributorsController do
  let(:user) { create(:user, :admin) }
  let(:contributor) { create(:contributor) }

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
      get :show, params: { id: contributor.id }
      expect(response).to have_http_status(:success)
    end
  end
end
