require 'rails_helper'

RSpec.describe "Query Optimization", type: :request do
  let(:user) { create(:user, :admin) }
  let(:repository) { create(:repository) }
  let(:week) { create(:week, repository: repository) }

  before do
    sign_in user
  end

  describe "WeeksController#pr_list" do
    let!(:pull_requests) do
      3.times.map do |i|
        pr = create(:pull_request,
                    repository: repository,
                    gh_created_at: week.begin_date + i.hours,
                    ready_for_review_at: week.begin_date + i.hours
                   )
        create(:review, pull_request: pr, submitted_at: week.begin_date + 2.days)
        pr.update_week_associations
        pr
      end
    end

    it "loads started PRs with proper includes" do
      get pr_list_repository_week_path(repository, week, category: 'started'), xhr: true
      expect(response).to be_successful
      expect(response.body).to include(pull_requests.first.title)
    end

    it "loads all PR categories without errors" do
      %w[started open first_reviewed merged cancelled draft].each do |category|
        get pr_list_repository_week_path(repository, week, category: category), xhr: true
        expect(response).to be_successful
      end
    end
  end

  describe "PullRequestUsersController#index" do
    let(:pull_request) { create(:pull_request, repository: repository) }
    let!(:pull_request_users) do
      3.times.map { create(:pull_request_user, pull_request: pull_request) }
    end

    it "loads pull request users with includes" do
      get pull_request_pull_request_users_path(pull_request)
      expect(response).to be_successful
      expect(response.body).to include(pull_request_users.first.user.username)
    end
  end

  describe "ContributorsController#show" do
    let(:contributor) { create(:contributor) }
    let!(:pull_request_users) do
      3.times.map { create(:pull_request_user, user: contributor) }
    end

    it "loads contributor's pull requests with includes" do
      get contributor_path(contributor)
      expect(response).to be_successful
      expect(response.body).to include(pull_request_users.first.pull_request.title)
    end
  end
end
