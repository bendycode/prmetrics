require 'rails_helper'

# Every page under a repository consults RepositoryPolicy#show? for that
# repository, so a rule that tightens who may see a repository applies to
# its weeks, pull requests, reviews, and participants at the same time.
RSpec.describe 'Repository Data Authorization' do
  let(:user) { create(:user) }
  let(:repository) { create(:repository) }
  let(:week) { create(:week, repository: repository) }
  let(:pull_request) { create(:pull_request, repository: repository) }
  let(:review) { create(:review, pull_request: pull_request) }
  let(:pull_request_user) { create(:pull_request_user, pull_request: pull_request) }

  before { sign_in user }

  shared_examples 'a page governed by the repository policy' do
    it 'redirects home when the repository policy denies the owning repository' do
      denying_policy = instance_double(RepositoryPolicy, show?: false)
      allow(RepositoryPolicy).to receive(:new).with(user, repository).and_return(denying_policy)

      get path

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq('You are not authorized')
    end
  end

  shared_examples 'a page open to regular users' do
    it 'renders for a regular user' do
      get path

      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET /repositories/:repository_id/pull_requests' do
    let(:path) { repository_pull_requests_path(repository) }

    it_behaves_like 'a page governed by the repository policy'
  end

  describe 'GET /pull_requests/:id' do
    let(:path) { pull_request_path(pull_request) }

    it_behaves_like 'a page governed by the repository policy'
  end

  describe 'GET /repositories/:repository_id/weeks/:id' do
    let(:path) { repository_week_path(repository, week) }

    it_behaves_like 'a page governed by the repository policy'
    it_behaves_like 'a page open to regular users'
  end

  describe 'GET /repositories/:repository_id/weeks/:id/pr_list' do
    let(:path) { pr_list_repository_week_path(repository, week, category: 'started') }

    it_behaves_like 'a page governed by the repository policy'
    it_behaves_like 'a page open to regular users'
  end

  describe 'GET /pull_requests/:pull_request_id/reviews' do
    let(:path) { pull_request_reviews_path(pull_request) }

    it_behaves_like 'a page governed by the repository policy'
  end

  describe 'GET /reviews/:id' do
    let(:path) { review_path(review) }

    it_behaves_like 'a page governed by the repository policy'
    it_behaves_like 'a page open to regular users'
  end

  describe 'GET /pull_requests/:pull_request_id/pull_request_users' do
    let(:path) { pull_request_pull_request_users_path(pull_request) }

    it_behaves_like 'a page governed by the repository policy'
  end

  describe 'GET /pull_request_users/:id' do
    let(:path) { pull_request_user_path(pull_request_user) }

    it_behaves_like 'a page governed by the repository policy'
    it_behaves_like 'a page open to regular users'
  end
end
