require 'rails_helper'

RSpec.describe DashboardController do
  let(:user) { create(:user, :admin) }

  before do
    sign_in user
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
        expect(chart_weeks).to match_array([week1])
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

      context 'with all nil values' do
        let!(:all_nil_repo) { create(:repository, name: 'test/all-nils') }
        let!(:nil_week1) { create(:week, repository: all_nil_repo, begin_date: 1.week.ago,
                                   num_prs_started: nil, num_prs_merged: nil, num_prs_cancelled: nil) }
        let!(:nil_week2) { create(:week, repository: all_nil_repo, begin_date: 2.weeks.ago,
                                   num_prs_started: nil, num_prs_merged: nil, num_prs_cancelled: nil) }

        it "handles all nil weeks without crashing" do
          expect {
            get :index, params: { repository_id: all_nil_repo.id }
          }.not_to raise_error
          expect(response).to have_http_status(:success)
        end
      end
    end

  end
end