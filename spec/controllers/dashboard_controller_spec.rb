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
    
    context "with nil values in week records" do
      let!(:repo_with_nils) { create(:repository, name: 'test/nil-values') }
      let!(:week_with_nils) { create(:week, repository: repo_with_nils, begin_date: 1.week.ago, 
                                     num_prs_started: nil, num_prs_merged: nil, num_prs_cancelled: nil) }
      let!(:normal_week) { create(:week, repository: repo_with_nils, begin_date: 2.weeks.ago,
                                  num_prs_started: 5, num_prs_merged: 3, num_prs_cancelled: 1) }
      
      it "handles nil values without crashing" do
        expect {
          get :index, params: { repository_id: repo_with_nils.id }
        }.not_to raise_error
        expect(response).to have_http_status(:success)
      end
      
      it "treats nil values as zero in aggregations" do
        get :index, params: { repository_id: repo_with_nils.id }
        
        # Should not crash and should handle nils as zeros
        expect(response).to have_http_status(:success)
        
        # Repository stats should handle nils properly
        repo_stats = assigns(:repository_stats)
        test_repo_stat = repo_stats.find { |stat| stat[:name] == 'test/nil-values' }
        expect(test_repo_stat[:total_prs]).to eq(5) # Only the normal week's value
      end
      
      it "handles all nil weeks without crashing" do
        # Create a repository with only nil weeks
        all_nil_repo = create(:repository, name: 'test/all-nils')
        create(:week, repository: all_nil_repo, begin_date: 1.week.ago,
               num_prs_started: nil, num_prs_merged: nil, num_prs_cancelled: nil)
        create(:week, repository: all_nil_repo, begin_date: 2.weeks.ago,
               num_prs_started: nil, num_prs_merged: nil, num_prs_cancelled: nil)
        
        expect {
          get :index, params: { repository_id: all_nil_repo.id }
        }.not_to raise_error
        expect(response).to have_http_status(:success)
      end
    end

    context "approved PRs aggregation" do
      let!(:repo1) { create(:repository, name: 'test/repo1') }
      let!(:repo2) { create(:repository, name: 'test/repo2') }
      let!(:week_date) { Date.new(2024, 1, 8) }
      let!(:week1_repo1) { create(:week, repository: repo1, begin_date: week_date, week_number: 202402) }
      let!(:week1_repo2) { create(:week, repository: repo2, begin_date: week_date, week_number: 202402) }

      before do
        # Create approved PRs for aggregation testing
        create(:pull_request, :approved, repository: repo1, gh_created_at: week_date)
        create(:pull_request, :approved, repository: repo1, gh_created_at: week_date)
        create(:pull_request, :approved, repository: repo2, gh_created_at: week_date)
        create(:pull_request, :with_comments, repository: repo1, gh_created_at: week_date) # unapproved
      end

      it "aggregates approved PRs from multiple repositories" do
        get :index
        chart_weeks = assigns(:chart_weeks)

        # Find the aggregated week for our test date
        aggregated_week = chart_weeks.find { |w| w.begin_date == week_date }
        expect(aggregated_week).to be_present
        expect(aggregated_week.num_prs_approved).to eq(3) # 2 from repo1 + 1 from repo2
      end

      it "handles nil values in approved aggregation" do
        # Create weeks with mixed approved/nil scenarios
        nil_week = create(:week, repository: repo1, begin_date: 2.weeks.ago, week_number: 202350)

        allow_any_instance_of(Week).to receive(:num_prs_approved).and_return(nil)

        expect {
          get :index
        }.not_to raise_error
        expect(response).to have_http_status(:success)
      end

      it "includes num_prs_approved method on aggregated weeks" do
        get :index
        chart_weeks = assigns(:chart_weeks)

        aggregated_week = chart_weeks.first
        expect(aggregated_week).to respond_to(:num_prs_approved)
      end
    end
  end
end