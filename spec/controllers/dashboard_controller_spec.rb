require 'rails_helper'

RSpec.describe DashboardController, type: :controller do
  let(:admin) { create(:admin) }
  
  before do
    sign_in admin
  end

  describe "GET #index" do
    let!(:repo1) { create(:repository, name: 'rails/rails') }
    let!(:repo2) { create(:repository, name: 'ruby/ruby') }
    let!(:week1) { create(:week, repository: repo1, begin_date: 1.week.ago, num_prs_started: 10, num_prs_merged: 8) }
    let!(:week2) { create(:week, repository: repo2, begin_date: 1.week.ago, num_prs_started: 5, num_prs_merged: 3) }
    
    context "without repository filter" do
      it "returns http success" do
        get :index
        expect(response).to have_http_status(:success)
      end
      
      it "shows all repositories" do
        get :index
        expect(assigns(:repositories)).to match_array([repo1, repo2])
      end
      
      it "aggregates data from all repositories" do
        get :index
        expect(assigns(:total_prs)).to eq(PullRequest.count)
      end
    end
    
    context "with repository filter" do
      it "filters data by selected repository" do
        get :index, params: { repository_id: repo1.id }
        expect(assigns(:selected_repository_id)).to eq(repo1.id.to_s)
      end
      
      it "shows filtered week data" do
        get :index, params: { repository_id: repo1.id }
        chart_weeks = assigns(:chart_weeks)
        expect(chart_weeks).to include(week1)
        expect(chart_weeks).not_to include(week2)
      end
    end
  end
end