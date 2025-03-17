require 'rails_helper'

RSpec.describe GithubService do
  let(:access_token) { 'mock_access_token' }
  let(:service) { GithubService.new(access_token) }
  let(:octokit_client) { instance_double(Octokit::Client) }
  let(:repository) { create(:repository, name: 'test/repo') }

  before do
    allow(Octokit::Client).to receive(:new).and_return(octokit_client)
    allow(octokit_client).to receive(:auto_paginate=)
  end

  describe '#fetch_and_store_reviews' do
    let(:pull_request) { create(:pull_request, repository: repository, ready_for_review_at: 2.days.ago) }
    let(:pr_number) { pull_request.number }
    let(:repo_name) { repository.name }
    let(:user) { double('github_user', login: 'reviewer', name: 'Reviewer', email: 'reviewer@example.com', id: '123') }

    context 'when reviews exist' do
      let(:valid_review) { double('review', state: 'approved', submitted_at: Time.current, user: user) }
      let(:early_review) { double('review', state: 'commented', submitted_at: 3.days.ago, user: user) }

      it 'stores all reviews regardless of timing' do
        allow(octokit_client).to receive(:pull_request_reviews).and_return([valid_review, early_review])
        allow(service).to receive(:find_or_create_user).and_return(create(:user))

        expect {
          service.send(:fetch_and_store_reviews, pull_request, repo_name, pr_number)
        }.to change(Review, :count).by(2)
      end
    end

    context 'when review timestamps are nil' do
      let(:invalid_review) { double('review', state: 'approved', submitted_at: nil, user: user) }

      it 'skips reviews with nil timestamps' do
        allow(octokit_client).to receive(:pull_request_reviews).and_return([invalid_review])

        expect {
          service.send(:fetch_and_store_reviews, pull_request, repo_name, pr_number)
        }.not_to change(Review, :count)
      end
    end
  end

  describe '#process_pull_request' do
    let(:github_user) { double('github_user', login: 'author', name: 'Author', email: 'author@example.com', id: '456', avatar_url: 'https://example.com/avatar.png') }
    let(:pr_data) do
      double('pr_data',
        number: 123,
        title: 'Test PR',
        state: 'open',
        draft: false,
        user: github_user,
        created_at: 2.days.ago,
        updated_at: 1.day.ago,
        merged_at: nil,
        closed_at: nil,
        merged_by: nil
      )
    end

    before do
      allow(service).to receive(:determine_ready_for_review_at).and_return(2.days.ago)
      allow(service).to receive(:find_or_create_github_user).and_return(create(:github_user))
      allow(service).to receive(:fetch_and_store_reviews)
      allow(service).to receive(:fetch_and_store_users)
    end

    it 'creates a pull request and sets ready_for_review_at' do
      expect {
        service.send(:process_pull_request, repository, 'test/repo', pr_data)
      }.to change(PullRequest, :count).by(1)

      pr = PullRequest.last
      expect(pr.ready_for_review_at).not_to be_nil
    end

    it 'does not set ready_for_review_at for draft PRs' do
      allow(pr_data).to receive(:draft).and_return(true)

      expect {
        service.send(:process_pull_request, repository, 'test/repo', pr_data)
      }.to change(PullRequest, :count).by(1)

      pr = PullRequest.last
      expect(pr.ready_for_review_at).to be_nil
    end

    it 'calls update_week_associations after processing' do
      expect_any_instance_of(PullRequest).to receive(:update_week_associations)
      service.send(:process_pull_request, repository, 'test/repo', pr_data)
    end
  end
end
