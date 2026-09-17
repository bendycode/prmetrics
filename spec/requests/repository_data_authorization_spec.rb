require 'rails_helper'

# A regular user reaches a repository's pages, and its weeks, pull requests,
# reviews, and participants, only when that repository was granted to them.
# Every other record answers not found, as a record that does not exist does,
# so the status never confirms which ids are real.
RSpec.describe 'Repository Data Authorization' do
  let(:user) { create(:user) }
  let(:repository) { create(:repository) }
  let(:week) { create(:week, repository: repository) }
  let(:pull_request) { create(:pull_request, repository: repository) }
  let(:review) { create(:review, pull_request: pull_request) }
  let(:pull_request_user) { create(:pull_request_user, pull_request: pull_request) }
  let(:missing_id) { 0 }

  before { sign_in user }

  shared_examples 'a page limited to granted repositories' do
    it 'renders when the owning repository is granted' do
      grant_access(user, repository)

      get path

      expect(response).to have_http_status(:success)
    end

    it 'answers not found when the owning repository is not granted' do
      grant_access(user, create(:repository))

      get path

      expect(response).to have_http_status(:not_found)
    end

    it 'answers not found for an id that does not exist' do
      grant_access(user, repository)

      get missing_path

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /repositories/:id' do
    let(:path) { repository_path(repository) }
    let(:missing_path) { repository_path(missing_id) }

    it_behaves_like 'a page limited to granted repositories'
  end

  describe 'GET /repositories/:repository_id/pull_requests' do
    let(:path) { repository_pull_requests_path(repository) }
    let(:missing_path) { repository_pull_requests_path(missing_id) }

    it_behaves_like 'a page limited to granted repositories'
  end

  describe 'GET /pull_requests/:id' do
    let(:path) { pull_request_path(pull_request) }
    let(:missing_path) { pull_request_path(missing_id) }

    it_behaves_like 'a page limited to granted repositories'
  end

  describe 'GET /repositories/:repository_id/weeks/:id' do
    let(:path) { repository_week_path(repository, week) }
    let(:missing_path) { repository_week_path(repository, missing_id) }

    it_behaves_like 'a page limited to granted repositories'
  end

  describe 'GET /repositories/:repository_id/weeks/:id/pr_list' do
    let(:path) { pr_list_repository_week_path(repository, week, category: 'started') }
    let(:missing_path) { pr_list_repository_week_path(repository, missing_id, category: 'started') }

    it_behaves_like 'a page limited to granted repositories'
  end

  describe 'GET /pull_requests/:pull_request_id/reviews' do
    let(:path) { pull_request_reviews_path(pull_request) }
    let(:missing_path) { pull_request_reviews_path(missing_id) }

    it_behaves_like 'a page limited to granted repositories'
  end

  describe 'GET /reviews/:id' do
    let(:path) { review_path(review) }
    let(:missing_path) { review_path(missing_id) }

    it_behaves_like 'a page limited to granted repositories'
  end

  describe 'GET /pull_requests/:pull_request_id/pull_request_users' do
    let(:path) { pull_request_pull_request_users_path(pull_request) }
    let(:missing_path) { pull_request_pull_request_users_path(missing_id) }

    it_behaves_like 'a page limited to granted repositories'
  end

  describe 'GET /pull_request_users/:id' do
    let(:path) { pull_request_user_path(pull_request_user) }
    let(:missing_path) { pull_request_user_path(missing_id) }

    it_behaves_like 'a page limited to granted repositories'
  end

  describe 'a week reached through a repository it does not belong to' do
    let(:other_repository) { create(:repository) }

    before { grant_access(user, repository, other_repository) }

    it 'answers not found for the week page even when both repositories are granted' do
      get repository_week_path(other_repository, week)

      expect(response).to have_http_status(:not_found)
    end

    it 'answers not found for the week pull request list even when both repositories are granted' do
      get pr_list_repository_week_path(other_repository, week, category: 'started')

      expect(response).to have_http_status(:not_found)
    end
  end
end
