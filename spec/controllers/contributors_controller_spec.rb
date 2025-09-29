require 'rails_helper'

RSpec.describe ContributorsController, type: :controller do
  let(:user) { create(:user, :admin) }

  before do
    sign_in user
  end
  let(:contributor) { create(:contributor) }

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
