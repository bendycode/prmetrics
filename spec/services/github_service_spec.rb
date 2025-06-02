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
        allow(service).to receive(:find_or_create_contributor).and_return(create(:contributor))

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
      allow(service).to receive(:find_or_create_contributor).and_return(create(:contributor))
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
      # The service calls it explicitly, and the model callback also calls it
      expect_any_instance_of(PullRequest).to receive(:update_week_associations).at_least(:once)
      service.send(:process_pull_request, repository, 'test/repo', pr_data)
    end
  end

  describe '#calculate_wait_time' do
    let(:current_time) { Time.new(2025, 3, 24, 17, 38, 29) }

    before do
      allow(Time).to receive(:now).and_return(current_time)
    end

    context 'when retry-after header is present' do
      it 'returns the retry-after value' do
        headers = { 'retry-after' => '30' }
        expect(service.send(:calculate_wait_time, headers, 0)).to eq(30)
      end
    end

    context 'when rate limit is exceeded' do
      context 'when reset time is in the future' do
        it 'calculates wait time based on reset time' do
          # Reset time is 5 minutes in the future
          reset_timestamp = current_time.to_i + 300
          headers = {
            'x-ratelimit-remaining' => '0',
            'x-ratelimit-reset' => reset_timestamp.to_s
          }

          expect(service.send(:calculate_wait_time, headers, 1)).to be_within(1).of(300)
        end
      end

      context 'when reset time has passed but still rate limited' do
        it 'uses exponential backoff based on retry count' do
          # Reset time is 5 seconds in the past
          reset_timestamp = current_time.to_i - 5
          headers = {
            'x-ratelimit-remaining' => '0',
            'x-ratelimit-reset' => reset_timestamp.to_s
          }

          # For retry_count = 0, should be 60 seconds
          expect(service.send(:calculate_wait_time, headers, 0)).to eq(60)

          # For retry_count = 1, should be 120 seconds
          expect(service.send(:calculate_wait_time, headers, 1)).to eq(120)

          # For retry_count = 2, should be 240 seconds
          expect(service.send(:calculate_wait_time, headers, 2)).to eq(240)
        end
      end
    end

    context 'when headers are incomplete' do
      it 'uses exponential backoff when x-ratelimit-reset is missing' do
        headers = { 'x-ratelimit-remaining' => '0' }
        expect(service.send(:calculate_wait_time, headers, 2)).to eq(240) # 60 * (2^2)
      end

      it 'uses exponential backoff when all rate limit headers are missing' do
        headers = { 'date' => 'Mon, 24 Mar 2025 17:38:29 GMT' }
        expect(service.send(:calculate_wait_time, headers, 3)).to eq(480) # 60 * (2^3)
      end
    end

    context 'when headers are nil' do
      it 'uses exponential backoff' do
        expect(service.send(:calculate_wait_time, nil, 4)).to eq(960) # 60 * (2^4)
      end
    end

    context 'when retry count exceeds reasonable limits' do
      it 'still calculates appropriate wait times for high retry counts' do
        # This tests that the calculation doesn't overflow or produce unexpected results
        headers = { 'date' => 'Mon, 24 Mar 2025 17:38:29 GMT' }
        expect(service.send(:calculate_wait_time, headers, 5)).to eq(1920) # 60 * (2^5)
      end
    end
  end
end
