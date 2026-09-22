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

        expect do
          service.send(:fetch_and_store_reviews, pull_request, repo_name, pr_number)
        end.to change(Review, :count).by(2)
      end
    end

    context 'when review timestamps are nil' do
      let(:invalid_review) { double('review', state: 'approved', submitted_at: nil, user: user) }

      it 'skips reviews with nil timestamps' do
        allow(octokit_client).to receive(:pull_request_reviews).and_return([invalid_review])

        expect do
          service.send(:fetch_and_store_reviews, pull_request, repo_name, pr_number)
        end.not_to change(Review, :count)
      end
    end
  end

  describe '#process_pull_request' do
    let(:github_user) do
      double('github_user', login: 'author', name: 'Author', email: 'author@example.com', id: '9000456',
                            avatar_url: 'https://example.com/avatar.png')
    end
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
             merged_by: nil,
             base: double(ref: 'main'),
             head: double(ref: 'feature/login'))
    end

    before do
      allow(service).to receive(:determine_ready_for_review_at).and_return(2.days.ago)
      allow(service).to receive(:fetch_and_store_reviews)
      allow(service).to receive(:fetch_and_store_users)
    end

    it 'creates a pull request and sets ready_for_review_at' do
      expect do
        service.send(:process_pull_request, repository, 'test/repo', pr_data)
      end.to change(PullRequest, :count).by(1)

      pr = PullRequest.last
      expect(pr.ready_for_review_at).not_to be_nil
    end

    it 'does not set ready_for_review_at for draft PRs' do
      allow(pr_data).to receive(:draft).and_return(true)

      expect do
        service.send(:process_pull_request, repository, 'test/repo', pr_data)
      end.to change(PullRequest, :count).by(1)

      pr = PullRequest.last
      expect(pr.ready_for_review_at).to be_nil
    end

    it 'raises when GitHub data fails validation instead of skipping the pull request' do
      existing = create(:pull_request, repository: repository, number: 123, title: 'Before')
      allow(pr_data).to receive(:title).and_return('')

      expect do
        service.send(:process_pull_request, repository, 'test/repo', pr_data)
      end.to raise_error(ActiveRecord::RecordInvalid)
      expect(existing.reload.title).to eq('Before')
    end

    it 'updates a pull request it has seen before and records its author' do
      existing = create(:pull_request, repository: repository, number: 123, title: 'Old title')

      service.send(:process_pull_request, repository, 'test/repo', pr_data)

      expect(existing.reload).to have_attributes(title: 'Test PR', author: have_attributes(username: 'author'))
    end

    it 'records the branch it merges into and the branch it comes from' do
      service.send(:process_pull_request, repository, 'test/repo', pr_data)

      expect(repository.pull_requests.find_by(number: 123)).to have_attributes(base_ref: 'main', head_ref: 'feature/login')
    end

    it 'leaves weeks to the processor' do
      expect do
        service.send(:process_pull_request, repository, 'test/repo', pr_data)
      end.not_to change(Week, :count)
    end
  end

  describe '#fetch_and_store_pull_requests' do
    let(:processed) { [] }
    let(:processor) { ->(pr) { processed << [pr.number, repository.pull_requests.exists?(number: pr.number)] } }

    def github_pr(number, updated_at)
      double("pr_#{number}",
             number: number, title: "PR #{number}", state: 'open', draft: false,
             user: double(id: 9_000_900 + number, login: "author#{number}", name: nil, avatar_url: nil, email: nil),
             created_at: updated_at - 1.day, updated_at: updated_at, merged_at: nil, closed_at: nil, merged_by: nil,
             base: double(ref: 'main'), head: double(ref: "feature/#{number}"))
    end

    def github_pages(*pages)
      allow(octokit_client).to receive(:pull_requests) do |_repo, options|
        pages[options[:page] - 1] || []
      end
    end

    before do
      allow(octokit_client).to receive_messages(issue_events: [], pull_request_reviews: [])
    end

    it 'stores every pull request on every page, then hands each to the processor' do
      github_pages([github_pr(1, 3.days.ago), github_pr(2, 2.days.ago)], [github_pr(3, 1.day.ago)])

      service.fetch_and_store_pull_requests(repository.name, processor: processor)

      expect(processed).to contain_exactly([1, true], [2, true], [3, true])
    end

    it 'records the newest update it saw as the repository\'s last fetch' do
      newest = 1.day.ago.change(usec: 0)
      github_pages([github_pr(1, newest), github_pr(2, 3.days.ago)])

      service.fetch_and_store_pull_requests(repository.name, processor: processor)

      expect(repository.reload.last_fetched_at).to eq(newest)
    end

    context 'with an earlier sync' do
      before do
        repository.update!(last_fetched_at: 2.days.ago)
        github_pages([github_pr(1, 1.day.ago), github_pr(2, 3.days.ago)], [github_pr(3, 4.days.ago)])
      end

      it 'skips pull requests unchanged since then and stops paging' do
        service.fetch_and_store_pull_requests(repository.name, processor: processor)

        expect(processed.map(&:first)).to eq([1])
        expect(octokit_client).to have_received(:pull_requests).twice
      end

      it 'fetches them all when asked for a full sync' do
        service.fetch_and_store_pull_requests(repository.name, processor: processor, fetch_all: true)

        expect(processed.map(&:first)).to contain_exactly(1, 2, 3)
      end
    end

    it 'refuses a repository that is not already stored' do
      expect do
        service.fetch_and_store_pull_requests('someone/unknown', processor: processor)
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'raises when the repository cannot record its last fetch' do
      github_pages([github_pr(1, 1.day.ago)])
      repository.name = 'not a repository name'
      repository.save(validate: false)

      expect do
        service.fetch_and_store_pull_requests(repository.name, processor: processor)
      end.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe '#fetch_and_store_users' do
    let(:pull_request) { create(:pull_request, repository: repository) }
    let(:author) { double(id: 9_000_501, login: 'the-author', name: nil, avatar_url: nil, email: nil) }
    let(:merger) { double(id: 9_000_502, login: 'the-merger', name: nil, avatar_url: nil, email: nil) }

    it 'records the author and the merger' do
      service.send(:fetch_and_store_users, pull_request, double(user: author, merged_by: merger))

      expect(pull_request.pull_request_users.map { |pru| [pru.role, pru.user.username] })
        .to contain_exactly(%w[author the-author], %w[merger the-merger])
    end

    it 'records only the author of an unmerged pull request' do
      service.send(:fetch_and_store_users, pull_request, double(user: author, merged_by: nil))

      expect(pull_request.pull_request_users.pluck(:role)).to eq(['author'])
    end

    it 'finds a contributor by username when GitHub sends no id' do
      existing = create(:contributor, username: 'no-id-user')
      username_only = double(login: 'no-id-user', name: nil, email: nil)

      service.send(:fetch_and_store_users, pull_request, double(user: username_only, merged_by: nil))

      expect(pull_request.pull_request_users.sole.user).to eq(existing)
    end
  end

  describe '#each_pull_request' do
    it 'yields every pull request on every page' do
      pages = [[double(number: 1), double(number: 2)], [double(number: 3)]]
      allow(octokit_client).to receive(:pull_requests) { |_repo, options| pages[options[:page] - 1] || [] }

      expect { |block| service.each_pull_request('owner/repo', &block) }
        .to yield_successive_args(*pages.flatten)
    end
  end

  describe '#default_branch' do
    it "reads the repository's default branch from GitHub" do
      allow(octokit_client).to receive(:repository).with('owner/repo').and_return(double(default_branch: 'main'))

      expect(service.default_branch('owner/repo')).to eq('main')
    end
  end

  describe '#determine_ready_for_review_at' do
    it 'returns ready_for_review event time when available' do
      ready_event = double(event: 'ready_for_review', created_at: 2.days.ago)
      other_event = double(event: 'labeled', created_at: 1.day.ago)
      allow(octokit_client).to receive(:issue_events).with('owner/repo', 123).and_return([other_event, ready_event])

      result = service.send(:determine_ready_for_review_at, 'owner/repo', 123, 3.days.ago)
      expect(result).to eq(ready_event.created_at)
    end

    it 'returns created_at when no ready_for_review event exists' do
      created_time = 3.days.ago
      allow(octokit_client).to receive(:issue_events).with('owner/repo', 123)
                                                     .and_return([double(event: 'labeled', created_at: 1.day.ago)])

      result = service.send(:determine_ready_for_review_at, 'owner/repo', 123, created_time)
      expect(result).to eq(created_time)
    end
  end

  describe '#with_rate_limit_handling' do
    before { allow(service).to receive(:sleep) }

    it 'yields to block when no errors' do
      expect(service.send(:with_rate_limit_handling) { 'success' }).to eq('success')
    end

    it 'retries on rate limit errors' do
      call_count = 0

      result = service.send(:with_rate_limit_handling) do
        call_count += 1
        if call_count == 1
          error = Octokit::TooManyRequests.new
          allow(error).to receive(:response_headers).and_return({ 'retry-after' => '1' })
          raise error
        end

        'success'
      end

      expect(result).to eq('success')
      expect(call_count).to eq(2)
      expect(service).to have_received(:sleep).with(1).once
    end

    it 'retries on connection errors' do
      call_count = 0

      result = service.send(:with_rate_limit_handling) do
        call_count += 1
        raise Faraday::ConnectionFailed, 'Connection failed' if call_count == 1

        'success'
      end

      expect(result).to eq('success')
      expect(call_count).to eq(2)
    end

    it 'raises after max retries' do
      expect do
        service.send(:with_rate_limit_handling) do
          error = Octokit::TooManyRequests.new
          allow(error).to receive(:response_headers).and_return(nil)
          raise error
        end
      end.to raise_error(/Max retries reached/)
      expect(service).to have_received(:sleep).exactly(GithubService::MAX_RETRIES).times
    end
  end

  describe '#calculate_wait_time' do
    let(:current_time) { Time.zone.local(2025, 3, 24, 17, 38, 29) }

    before do
      travel_to(current_time)
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

          expect(service.send(:calculate_wait_time, headers, 1)).to eq(300)
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
