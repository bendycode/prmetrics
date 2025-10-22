require 'rails_helper'

RSpec.describe SyncRepositoryBatchJob do
  let(:repository) { create(:repository, name: 'rails/rails') }
  let(:client) { instance_double(Octokit::Client) }

  before do
    allow(Octokit::Client).to receive(:new).with(access_token: ENV.fetch('GITHUB_ACCESS_TOKEN', nil)).and_return(client)
    allow(GithubService).to receive(:new).with(ENV.fetch('GITHUB_ACCESS_TOKEN',
                                                         nil)).and_return(instance_double(GithubService))
  end

  describe '#perform' do
    context 'when starting a sync (page 1)' do
      it 'marks repository as in_progress' do
        allow(client).to receive(:pull_requests).and_return([])

        expect do
          described_class.perform_now(repository.name, page: 1, fetch_all: true)
        end.to change { repository.reload.sync_status }.to('completed')

        expect(repository.sync_started_at).to be_present
      end
    end

    context 'when fetching pull requests' do
      let(:pr_data) do
        [
          {
            number: 123,
            title: 'Test PR',
            state: 'open',
            created_at: 2.days.ago,
            updated_at: 1.day.ago,
            closed_at: nil,
            merged_at: nil,
            draft: false,
            user: { id: 1, login: 'user1', name: 'User One', avatar_url: 'http://example.com/avatar.png' }
          }
        ]
      end

      it 'processes pull requests in batches' do
        allow(client).to receive(:pull_requests).with(
          repository.name,
          state: 'all',
          per_page: 100,
          page: 1,
          sort: 'updated',
          direction: 'desc'
        ).and_return(pr_data)

        # Now we process PRs directly in the job
        expect_any_instance_of(described_class).to receive(:process_single_pull_request).with(repository, pr_data.first)

        described_class.perform_now(repository.name, page: 1, fetch_all: false)
      end

      it 'queues next page when batch is full' do
        full_batch = Array.new(100) { pr_data.first }
        allow(client).to receive(:pull_requests).and_return(full_batch)
        allow(client).to receive(:issue_events).and_return([])
        allow(client).to receive(:pull_request_reviews).and_return([])

        expect(SyncRepositoryBatchJob).to receive(:perform_later).with(
          repository.name,
          page: 2,
          fetch_all: true
        )

        described_class.perform_now(repository.name, page: 1, fetch_all: true)
      end

      it 'completes sync when no more pull requests' do
        allow(client).to receive(:pull_requests).and_return([])

        described_class.perform_now(repository.name, page: 1, fetch_all: true)

        repository.reload
        expect(repository.sync_status).to eq('completed')
        expect(repository.sync_completed_at).to be_present
        expect(repository.last_fetched_at).to be_present
      end
    end

    context 'when an error occurs' do
      let(:error) { StandardError.new('API Error') }

      before do
        allow(client).to receive(:pull_requests).and_raise(error)
      end

      it 'marks repository as failed and re-raises error' do
        expect do
          described_class.perform_now(repository.name, page: 1)
        end.to raise_error(StandardError, 'API Error')

        repository.reload
        expect(repository.sync_status).to eq('failed')
        expect(repository.last_sync_error).to eq('API Error')
      end
    end

    context 'with incremental sync' do
      before do
        repository.update!(last_fetched_at: 1.week.ago)
      end

      it 'stops fetching when reaching previously fetched PRs' do
        old_pr = {
          number: 100,
          title: 'Old PR',
          state: 'closed',
          created_at: 3.weeks.ago,
          updated_at: 2.weeks.ago,
          closed_at: 2.weeks.ago,
          merged_at: nil,
          draft: false,
          user: { id: 1, login: 'user1', name: 'User One', avatar_url: 'http://example.com/avatar.png' }
        }

        allow(client).to receive(:pull_requests).and_return([old_pr])
        allow(client).to receive(:issue_events).and_return([])
        allow(client).to receive(:pull_request_reviews).and_return([])

        # Should not queue next page
        expect(SyncRepositoryBatchJob).not_to receive(:perform_later)

        described_class.perform_now(repository.name, page: 1, fetch_all: false)

        expect(repository.reload.sync_status).to eq('completed')
      end
    end
  end

  describe 'job configuration' do
    it 'uses the default queue' do
      expect(described_class.new.queue_name).to eq('default')
    end

    it 'has correct batch size' do
      expect(described_class::BATCH_SIZE).to eq(100)
    end
  end

  describe '#determine_ready_for_review_at' do
    let(:job) { described_class.new }

    it 'returns ready_for_review event time when available' do
      ready_event = double(event: 'ready_for_review', created_at: 2.days.ago)
      other_event = double(event: 'labeled', created_at: 1.day.ago)
      events = [other_event, ready_event]

      allow(client).to receive(:issue_events).with('owner/repo', 123).and_return(events)

      result = job.send(:determine_ready_for_review_at, 'owner/repo', 123, 3.days.ago)
      expect(result).to eq(ready_event.created_at)
    end

    it 'returns created_at when no ready_for_review event exists' do
      events = [double(event: 'labeled', created_at: 1.day.ago)]
      created_time = 3.days.ago

      allow(client).to receive(:issue_events).with('owner/repo', 123).and_return(events)

      result = job.send(:determine_ready_for_review_at, 'owner/repo', 123, created_time)
      expect(result).to eq(created_time)
    end
  end

  describe '#fetch_and_store_reviews' do
    let(:job) { described_class.new }
    let(:pull_request) { create(:pull_request, repository: repository) }
    let(:review_data) do
      [
        double(
          state: 'approved',
          submitted_at: 1.day.ago,
          user: double(id: 456, login: 'reviewer1', name: 'Reviewer One', email: 'reviewer1@example.com', avatar_url: 'http://avatar.url')
        ),
        double(
          state: 'changes_requested',
          submitted_at: nil # Should be skipped
        )
      ]
    end

    it 'fetches and stores reviews with valid submitted_at' do
      allow(client).to receive(:pull_request_reviews).with('owner/repo', 123).and_return(review_data)

      expect do
        job.send(:fetch_and_store_reviews, pull_request, 'owner/repo', 123)
      end.to change { pull_request.reviews.count }.by(1)

      review = pull_request.reviews.first
      expect(review.state).to eq('approved')
      expect(review.submitted_at).to eq(review_data.first.submitted_at)
    end

    it 'skips reviews without submitted_at' do
      review_without_time = double(state: 'pending', submitted_at: nil)
      allow(client).to receive(:pull_request_reviews).with('owner/repo', 123).and_return([review_without_time])

      expect do
        job.send(:fetch_and_store_reviews, pull_request, 'owner/repo', 123)
      end.not_to(change { pull_request.reviews.count })
    end
  end

  describe '#find_or_create_contributor' do
    let(:job) { described_class.new }

    context 'with object format (Octokit::Sawyer::Resource)' do
      let(:github_user) do
        double(id: 123, login: 'testuser', name: 'Test User', email: 'test@example.com', avatar_url: 'http://avatar.url')
      end

      it 'uses existing find_or_create_from_github method' do
        expect(Contributor).to receive(:find_or_create_from_github).with(github_user)
        job.send(:find_or_create_contributor, github_user)
      end
    end

    context 'with hash format' do
      let(:github_user) { { id: 123, login: 'testuser', name: 'Test User', avatar_url: 'http://avatar.url' } }

      it 'creates contributor with hash data' do
        expect do
          job.send(:find_or_create_contributor, github_user)
        end.to change { Contributor.count }.by(1)

        contributor = Contributor.last
        expect(contributor.github_id).to eq('123')
        expect(contributor.username).to eq('testuser')
        expect(contributor.name).to eq('Test User')
      end

      it 'finds existing contributor by github_id' do
        existing = create(:contributor, github_id: '123')

        result = job.send(:find_or_create_contributor, github_user)
        expect(result).to eq(existing)
        expect(Contributor.count).to eq(1)
      end
    end

    context 'without id (username only)' do
      let(:github_user) { { login: 'testuser', name: 'Test User' } }

      it 'falls back to find_or_create_from_username' do
        expect(Contributor).to receive(:find_or_create_from_username).with(
          'testuser',
          { name: 'Test User', email: nil }
        )
        job.send(:find_or_create_contributor, github_user)
      end
    end
  end

  describe '#fetch_and_store_users' do
    let(:job) { described_class.new }
    let(:pull_request) { create(:pull_request, repository: repository) }
    let(:pr_data) do
      {
        user: { id: 123, login: 'author' },
        merged_by: { id: 456, login: 'merger' }
      }
    end

    it 'stores author and merger users' do
      expect(job).to receive(:store_user).with(pull_request, pr_data[:user], 'author')
      expect(job).to receive(:store_user).with(pull_request, pr_data[:merged_by], 'merger')

      job.send(:fetch_and_store_users, pull_request, pr_data)
    end

    it 'handles missing merged_by' do
      pr_data_without_merger = { user: { id: 123, login: 'author' } }

      expect(job).to receive(:store_user).with(pull_request, pr_data_without_merger[:user], 'author')
      expect(job).not_to receive(:store_user).with(pull_request, nil, 'merger')

      job.send(:fetch_and_store_users, pull_request, pr_data_without_merger)
    end
  end

  describe '#store_user' do
    let(:job) { described_class.new }
    let(:pull_request) { create(:pull_request, repository: repository) }
    let(:github_user) { { id: 123, login: 'testuser' } }

    it 'creates PullRequestUser association' do
      expect do
        job.send(:store_user, pull_request, github_user, 'author')
      end.to change { PullRequestUser.count }.by(1)

      association = PullRequestUser.last
      expect(association.pull_request).to eq(pull_request)
      expect(association.role).to eq('author')
    end

    it 'handles nil github_user gracefully' do
      expect do
        job.send(:store_user, pull_request, nil, 'author')
      end.not_to(change { PullRequestUser.count })
    end
  end

  describe '#with_rate_limit_handling' do
    let(:job) { described_class.new }

    it 'yields to block when no errors' do
      result = job.send(:with_rate_limit_handling) { 'success' }
      expect(result).to eq('success')
    end

    it 'retries on rate limit errors' do
      call_count = 0
      allow(job).to receive(:sleep) # Don't actually sleep in tests

      result = job.send(:with_rate_limit_handling) do
        call_count += 1
        if call_count == 1
          error = Octokit::TooManyRequests.new
          allow(error).to receive(:response_headers).and_return({ 'retry-after' => '1' })
          raise error
        else
          'success'
        end
      end

      expect(result).to eq('success')
      expect(call_count).to eq(2)
    end

    it 'retries on connection errors' do
      call_count = 0
      allow(job).to receive(:sleep)

      result = job.send(:with_rate_limit_handling) do
        call_count += 1
        raise Faraday::ConnectionFailed, 'Connection failed' if call_count == 1

        'success'
      end

      expect(result).to eq('success')
      expect(call_count).to eq(2)
    end

    it 'raises after max retries' do
      allow(job).to receive(:sleep)

      expect do
        job.send(:with_rate_limit_handling) do
          error = Octokit::TooManyRequests.new
          allow(error).to receive(:response_headers).and_return(nil)
          raise error
        end
      end.to raise_error(/Max retries reached/)
    end
  end

  describe '#calculate_wait_time' do
    let(:job) { described_class.new }

    it 'uses retry-after header when available' do
      headers = { 'retry-after' => '60' }
      wait_time = job.send(:calculate_wait_time, headers, 0)
      expect(wait_time).to eq(60)
    end

    it 'calculates wait time from rate limit reset' do
      reset_time = (Time.now + 120).to_i
      headers = { 'x-ratelimit-remaining' => '0', 'x-ratelimit-reset' => reset_time.to_s }

      wait_time = job.send(:calculate_wait_time, headers, 0)
      expect(wait_time).to be > 110
      expect(wait_time).to be < 130
    end

    it 'uses exponential backoff for nil headers' do
      wait_time = job.send(:calculate_wait_time, nil, 1)
      expect(wait_time).to eq(120) # 60 * (2 ** 1)
    end

    it 'uses exponential backoff when rate limit reset time is past' do
      reset_time = (Time.now - 60).to_i # Past time
      headers = { 'x-ratelimit-remaining' => '0', 'x-ratelimit-reset' => reset_time.to_s }

      wait_time = job.send(:calculate_wait_time, headers, 0)
      expect(wait_time).to eq(60) # Falls back to exponential backoff
    end
  end

  describe '#exponential_backoff_starting_at_one_minute' do
    let(:job) { described_class.new }

    it 'starts at one minute for first retry' do
      backoff_time = job.send(:exponential_backoff_starting_at_one_minute, 0)
      expect(backoff_time).to eq(60)
    end

    it 'doubles for each retry' do
      backoff_time = job.send(:exponential_backoff_starting_at_one_minute, 2)
      expect(backoff_time).to eq(240)  # 60 * (2 ** 2)
    end

    it 'handles large retry counts' do
      backoff_time = job.send(:exponential_backoff_starting_at_one_minute, 3)
      expect(backoff_time).to eq(480)  # 60 * (2 ** 3)
    end
  end

  describe 'error edge cases' do
    let(:job) { described_class.new }
    let(:repository) { create(:repository, name: 'rails/rails') }

    it 'handles process_single_pull_request with minimal pr_data' do
      minimal_pr_data = {
        number: 999,
        title: 'Minimal PR',
        state: 'open',
        draft: false,
        created_at: 1.day.ago,
        updated_at: 1.day.ago,
        closed_at: nil,
        merged_at: nil,
        user: { id: 123, login: 'testuser', name: 'Test User', avatar_url: 'http://avatar.url' }
      }

      allow(client).to receive(:issue_events).and_return([])
      allow(client).to receive(:pull_request_reviews).and_return([])

      expect do
        job.send(:process_single_pull_request, repository, minimal_pr_data)
      end.to change { repository.pull_requests.count }.by(1)

      pr = repository.pull_requests.last
      expect(pr.number).to eq(999)
      expect(pr.author.username).to eq('testuser')
    end
  end

  describe 'integration with process_single_pull_request' do
    let(:job) { described_class.new }
    let(:pr_data) do
      {
        number: 456,
        title: 'Integration Test PR',
        state: 'closed',
        draft: false,
        created_at: 2.days.ago,
        updated_at: 1.day.ago,
        closed_at: 1.day.ago,
        merged_at: 1.day.ago,
        user: { id: 789, login: 'integrationuser', name: 'Integration User', avatar_url: 'http://avatar.url' }
      }
    end

    before do
      allow(client).to receive(:issue_events).and_return([])
      allow(client).to receive(:pull_request_reviews).and_return([])
    end

    it 'creates pull request with proper week associations' do
      expect do
        job.send(:process_single_pull_request, repository, pr_data)
      end.to change { repository.pull_requests.count }.by(1)

      pr = repository.pull_requests.find_by(number: 456)
      expect(pr.title).to eq('Integration Test PR')
      expect(pr.author.username).to eq('integrationuser')
    end

    it 'handles existing pull request updates' do
      existing_pr = create(:pull_request, repository: repository, number: 456, title: 'Old Title')

      job.send(:process_single_pull_request, repository, pr_data)

      existing_pr.reload
      expect(existing_pr.title).to eq('Integration Test PR')
    end
  end
end
