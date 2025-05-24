require 'rails_helper'

RSpec.describe UsersController, type: :controller do
  let(:admin) { create(:admin) }
  
  before do
    sign_in admin
  end
  let(:user) { create(:user) }

  describe "GET #index" do
    it "returns http success" do
      get :index
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET #show" do
    it "returns http success" do
      get :show, params: { id: user.id }
      expect(response).to have_http_status(:success)
    end
  end
end
