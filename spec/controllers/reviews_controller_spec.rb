require 'rails_helper'

RSpec.describe ReviewsController, type: :controller do
  let(:admin) { create(:admin) }
  
  before do
    sign_in admin
  end
  let(:pull_request) { create :pull_request }
  let(:author) { create :user }
  let(:review) { create :review, pull_request: pull_request, author: author }

  describe "GET #index" do
    it "returns http success" do
      get :index, params: { pull_request_id: pull_request.id }
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET #show" do
    it "returns http success" do
      get :show, params: { id: review.id }
      expect(response).to have_http_status(:success)
    end
  end
end
