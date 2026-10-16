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

  describe '#store_reviews' do
    let(:pull_request) { create(:pull_request, repository: repository, ready_for_review_at: 2.days.ago) }
    let(:user) { double('github_user', login: 'reviewer', name: 'Reviewer', email: 'reviewer@example.com', id: '123') }

    it 'stores all reviews regardless of timing' do
      reviews = [double('review', state: 'approved', submitted_at: Time.current, user: user),
                 double('review', state: 'commented', submitted_at: 3.days.ago, user: user)]
      allow(service).to receive(:find_or_create_contributor).and_return(create(:contributor))

      expect do
        service.send(:store_reviews, pull_request, reviews)
      end.to change(Review, :count).by(2)
    end

    it 'skips reviews with nil timestamps' do
      reviews = [double('review', state: 'approved', submitted_at: nil, user: user)]

      expect do
        service.send(:store_reviews, pull_request, reviews)
      end.not_to change(Review, :count)
    end
  end

  describe '#pull_request_reviews' do
    it 'reads the reviews on every page' do
      pages = [Array.new(100) { |n| double(state: 'COMMENTED', submitted_at: n.hours.ago) },
               [double(state: 'APPROVED', submitted_at: Time.current)]]
      allow(octokit_client).to receive(:pull_request_reviews) do |_repo, _number, options|
        pages[options[:page] - 1] || []
      end

      expect(service.send(:pull_request_reviews, repository.name, 123).size).to be(101)
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
             base: double(ref: 'main'),
             head: double(ref: 'feature/login', repo: double(full_name: 'test/repo')))
    end

    before do
      allow(service).to receive(:issue_events).and_return([])
      allow(octokit_client).to receive(:pull_request_reviews).and_return([])
      allow(service).to receive(:store_author)
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

    # A pull request stored at the update GitHub lists is skipped by the next
    # incremental sync, so it has to be stored whole or not at all.
    context 'when storing it fails partway' do
      let(:stored_at) { 3.days.ago.change(usec: 0) }
      let!(:existing) { create(:pull_request, repository: repository, number: 123, gh_updated_at: stored_at) }

      it 'keeps the update it was stored at when GitHub fails to list its reviews' do
        allow(octokit_client).to receive(:pull_request_reviews).and_raise(Octokit::ServerError)

        expect do
          service.send(:process_pull_request, repository, 'test/repo', pr_data)
        end.to raise_error(Octokit::ServerError)
        expect(existing.reload.gh_updated_at).to eq(stored_at)
      end

      it 'keeps the update it was stored at when its author cannot be recorded' do
        allow(service).to receive(:store_author).and_raise(ActiveRecord::RecordInvalid)

        expect do
          service.send(:process_pull_request, repository, 'test/repo', pr_data)
        end.to raise_error(ActiveRecord::RecordInvalid)
        expect(existing.reload.gh_updated_at).to eq(stored_at)
      end
    end

    it 'updates a pull request it has seen before and records its author' do
      existing = create(:pull_request, repository: repository, number: 123, title: 'Old title')

      service.send(:process_pull_request, repository, 'test/repo', pr_data)

      expect(existing.reload).to have_attributes(title: 'Test PR', author: have_attributes(username: 'author'))
    end

    context 'when GitHub says it was merged' do
      let(:merger) { double(id: 9_000_777, login: 'the-merger', name: nil, avatar_url: nil, email: nil, type: 'User') }

      before do
        allow(pr_data).to receive_messages(merged_at: 1.day.ago, state: 'closed')
        labeller = double(id: 9_000_778, login: 'the-labeller', name: nil, avatar_url: nil, email: nil, type: 'User')
        allow(service).to receive(:issue_events).and_return([double(event: 'merged', actor: merger),
                                                             double(event: 'labeled', actor: labeller)])
      end

      it 'records who merged it, from the merge event' do
        service.send(:process_pull_request, repository, 'test/repo', pr_data)

        expect(repository.pull_requests.find_by(number: 123).merged_by).to have_attributes(username: 'the-merger')
      end

      it 'records a merger GitHub calls a Bot as one, whatever its login looks like' do
        allow(merger).to receive_messages(type: 'Bot', login: 'copilot-style-name')

        service.send(:process_pull_request, repository, 'test/repo', pr_data)

        expect(repository.pull_requests.find_by(number: 123).merged_by).to be_bot
      end
    end

    it 'keeps a merger it already knows when GitHub reports no merge event' do
      recorded = create(:contributor, username: 'recorded-earlier')
      create(:pull_request, repository: repository, number: 123, gh_merged_at: 1.day.ago, merged_by: recorded)
      allow(pr_data).to receive_messages(merged_at: 1.day.ago, state: 'closed')

      service.send(:process_pull_request, repository, 'test/repo', pr_data)

      expect(repository.pull_requests.find_by(number: 123).merged_by).to eq(recorded)
    end

    it 'keeps a merger it already knows when the one GitHub names cannot be stored' do
      recorded = create(:contributor, username: 'recorded-earlier')
      create(:pull_request, repository: repository, number: 123, gh_merged_at: 1.day.ago, merged_by: recorded)
      create(:contributor, username: 'the-merger', github_id: 'placeholder_earlier')
      merger = double(id: 9_000_781, login: 'the-merger', name: nil, avatar_url: nil, email: nil, type: 'User')
      allow(pr_data).to receive_messages(merged_at: 1.day.ago, state: 'closed')
      allow(service).to receive(:issue_events).and_return([double(event: 'merged', actor: merger)])

      service.send(:process_pull_request, repository, 'test/repo', pr_data)

      expect(repository.pull_requests.find_by(number: 123).merged_by).to eq(recorded)
    end

    it 'leaves the merger empty while a pull request is open, whatever its events say' do
      merger = double(id: 9_000_779, login: 'too-early', name: nil, avatar_url: nil, email: nil, type: 'User')
      allow(service).to receive(:issue_events).and_return([double(event: 'merged', actor: merger)])

      service.send(:process_pull_request, repository, 'test/repo', pr_data)

      expect(repository.pull_requests.find_by(number: 123).merged_by).to be_nil
    end

    it 'reads the events of the pull request it is processing' do
      service.send(:process_pull_request, repository, 'test/repo', pr_data)

      expect(service).to have_received(:issue_events).with('test/repo', 123)
    end

    it 'records the merger of a draft that was merged' do
      merger = double(id: 9_000_780, login: 'draft-merger', name: nil, avatar_url: nil, email: nil, type: 'User')
      allow(pr_data).to receive_messages(draft: true, merged_at: 1.day.ago, state: 'closed')
      allow(service).to receive(:issue_events).and_return([double(event: 'merged', actor: merger)])

      service.send(:process_pull_request, repository, 'test/repo', pr_data)

      expect(repository.pull_requests.find_by(number: 123))
        .to have_attributes(ready_for_review_at: nil, merged_by: have_attributes(username: 'draft-merger'))
    end

    it 'records the branch it merges into and the branch it comes from' do
      service.send(:process_pull_request, repository, 'test/repo', pr_data)

      expect(repository.pull_requests.find_by(number: 123))
        .to have_attributes(base_ref: 'main', head_ref: 'feature/login', head_repository: 'test/repo')
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
             base: double(ref: 'main'),
             head: double(ref: "feature/#{number}", repo: double(full_name: 'test/repo')))
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

    it 'returns the newest update it saw, leaving the last fetch for the caller to record' do
      newest = 1.day.ago.change(usec: 0)
      github_pages([github_pr(1, newest), github_pr(2, 3.days.ago)])
      returned = nil

      expect do
        returned = service.fetch_and_store_pull_requests(repository.name, processor: processor)
      end.not_to(change { repository.reload.last_fetched_at })
      expect(returned).to eq(newest)
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

      # GitHub's list endpoint has no since parameter; the cutoff is applied
      # to each page here.
      it 'sends GitHub no since parameter' do
        service.fetch_and_store_pull_requests(repository.name, processor: processor)

        expect(octokit_client).to have_received(:pull_requests).with(repository.name, hash_excluding(:since)).twice
      end

      it 'fetches them all when asked for a full sync' do
        service.fetch_and_store_pull_requests(repository.name, processor: processor, fetch_all: true)

        expect(processed.map(&:first)).to contain_exactly(1, 2, 3)
      end
    end

    context 'when a pull request was updated in the same second as the last fetch' do
      let(:last_fetch) { 2.days.ago.change(usec: 0) }

      before do
        # The pull request whose update set the last fetch
        create(:pull_request, repository: repository, number: 1, gh_updated_at: last_fetch)
        repository.update!(last_fetched_at: last_fetch)
        github_pages([github_pr(2, last_fetch), github_pr(1, last_fetch)], [github_pr(3, last_fetch - 1.day)])
      end

      it 'stores it' do
        service.fetch_and_store_pull_requests(repository.name, processor: processor)

        expect(repository.pull_requests).to exist(number: 2)
      end
    end

    # GitHub's timestamps are whole seconds, so a pull request read in the
    # second it last changed can change again in that second without its
    # updated_at moving.
    context 'when pull requests are stored at the update GitHub lists' do
      let(:newest_stored) { 2.days.ago.change(usec: 0) }
      let(:details_fetched_for) { [] }

      before do
        create(:pull_request, repository: repository, number: 1, gh_updated_at: newest_stored)
        create(:pull_request, repository: repository, number: 2, gh_updated_at: newest_stored - 1.day)
        # An author whose login another contributor holds is not saved, and
        # the pull request is stored without one
        taken = create(:contributor).username
        create(:pull_request, repository: repository, number: 3, gh_updated_at: newest_stored - 1.day,
                              author: Contributor.new(username: taken, github_id: '9000999'))
        repository.update!(last_fetched_at: newest_stored - 2.days)
        github_pages([github_pr(1, newest_stored), github_pr(2, newest_stored - 1.day),
                      github_pr(3, newest_stored - 1.day)])
        allow(octokit_client).to receive(:pull_request_reviews) do |_repo, number, _options|
          details_fetched_for << number
          []
        end
      end

      it 'reads again only the one stored in the newest second and the one stored without its author' do
        service.fetch_and_store_pull_requests(repository.name, processor: processor)

        expect(details_fetched_for).to contain_exactly(1, 3)
      end
    end

    context 'when a walk fails partway and the sync runs again' do
      let(:last_fetch) { 5.days.ago.change(usec: 0) }
      let(:first_page) { [github_pr(1, last_fetch + 3.days), github_pr(2, last_fetch + 2.days)] }
      let(:second_page) { [github_pr(3, last_fetch + 1.day)] }
      let(:details_fetched_for) { [] }

      before do
        repository.update!(last_fetched_at: last_fetch)
        allow(octokit_client).to receive(:issue_events) do |_repo, number, _options|
          details_fetched_for << number
          []
        end
        allow(octokit_client).to receive(:pull_request_reviews) do |_repo, number, _options|
          details_fetched_for << number
          []
        end
        fail_the_walk_on_the_second_page
        github_pages(first_page, second_page)
        details_fetched_for.clear
        processed.clear
      end

      def fail_the_walk_on_the_second_page
        allow(octokit_client).to receive(:pull_requests) do |_repo, options|
          raise Octokit::ServerError if options[:page] == 2

          first_page
        end
        service.fetch_and_store_pull_requests(repository.name, processor: processor)
        raise 'the first walk was meant to fail on its second page'
      rescue Octokit::ServerError
        nil
      end

      it 'fetches details again only for what the failed walk missed and the newest it stored' do
        service.fetch_and_store_pull_requests(repository.name, processor: processor)

        expect(details_fetched_for.uniq).to contain_exactly(1, 3)
      end

      # A pull request whose GitHub reads are skipped still has its weeks
      # recalculated.
      it 'still hands every pull request in the window to the processor' do
        service.fetch_and_store_pull_requests(repository.name, processor: processor)

        expect(processed.map(&:first)).to contain_exactly(1, 2, 3)
      end

      it 'fetches details for every pull request again on a full refresh' do
        service.fetch_and_store_pull_requests(repository.name, processor: processor, fetch_all: true)

        expect(details_fetched_for.uniq).to contain_exactly(1, 2, 3)
      end
    end

    it 'refuses a repository that is not already stored' do
      expect do
        service.fetch_and_store_pull_requests('someone/unknown', processor: processor)
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe '#store_author' do
    let(:pull_request) { create(:pull_request, repository: repository) }
    let(:author) { double(id: 9_000_501, login: 'the-author', name: nil, avatar_url: nil, email: nil) }

    it "records the pull request's author as a participant" do
      service.send(:store_author, pull_request, double(user: author))

      expect(pull_request.pull_request_users.map { |pru| [pru.role, pru.user.username] })
        .to contain_exactly(%w[author the-author])
    end

    it 'finds a contributor by username when GitHub sends no id' do
      existing = create(:contributor, username: 'no-id-user')
      username_only = double(login: 'no-id-user', name: nil, email: nil)

      service.send(:store_author, pull_request, double(user: username_only))

      expect(pull_request.pull_request_users.sole.user).to eq(existing)
    end
  end

  describe '#merged_pull_requests' do
    # The shape Octokit returns for a GraphQL response
    def graphql_page(nodes, has_next_page: false, end_cursor: nil)
      Sawyer::Resource.new(Sawyer::Agent.new('https://api.github.com'),
                           data: { repository: { pullRequests: {
                             pageInfo: { hasNextPage: has_next_page, endCursor: end_cursor }, nodes: nodes
                           } } })
    end

    it 'answers with each merged pull request and its merger' do
      allow(octokit_client).to receive(:post).and_return(
        graphql_page([{ number: 1, mergedBy: { login: 'one', databaseId: 11, __typename: 'User' } },
                      { number: 2, mergedBy: { login: 'two[bot]', databaseId: 22, __typename: 'Bot' } }],
                     has_next_page: true, end_cursor: 'cursor-1')
      )

      expect(service.merged_pull_requests('owner/app')).to eq(
        nodes: [{ number: 1, merged_by: { login: 'one', id: 11, type: 'User' } },
                { number: 2, merged_by: { login: 'two[bot]', id: 22, type: 'Bot' } }],
        has_next_page: true, end_cursor: 'cursor-1'
      )
    end

    it 'asks about that repository, from the cursor it is given' do
      allow(octokit_client).to receive(:post).and_return(graphql_page([]))

      service.merged_pull_requests('owner/app', after: 'cursor-1')

      posted = nil
      expect(octokit_client).to have_received(:post) { |_path, body| posted = JSON.parse(body) }
      expect(posted['variables']).to eq('owner' => 'owner', 'name' => 'app', 'after' => 'cursor-1')
    end

    it 'says what GitHub complained about rather than dying on an empty answer' do
      errors = Sawyer::Resource.new(Sawyer::Agent.new('https://api.github.com'),
                                    data: nil, errors: [{ message: 'Bad credentials' }])
      allow(octokit_client).to receive(:post).and_return(errors)

      expect { service.merged_pull_requests('owner/app') }.to raise_error(/Bad credentials/)
    end

    it 'says so when the repository is not one the token can see' do
      missing = Sawyer::Resource.new(Sawyer::Agent.new('https://api.github.com'), data: { repository: nil })
      allow(octokit_client).to receive(:post).and_return(missing)

      expect { service.merged_pull_requests('owner/app') }.to raise_error(%r{owner/app})
    end

    it 'waits and retries when GitHub answers that the query is rate limited' do
      limited = Sawyer::Resource.new(Sawyer::Agent.new('https://api.github.com'),
                                     data: nil, errors: [{ type: 'RATE_LIMITED', message: 'API rate limit exceeded' }])
      allow(service).to receive(:sleep)
      allow(octokit_client).to receive(:post).and_return(limited, graphql_page([]))

      service.merged_pull_requests('owner/app')

      expect(service).to have_received(:sleep).once
    end

    it 'reports no merger for a pull request whose merger GitHub no longer knows' do
      allow(octokit_client).to receive(:post).and_return(graphql_page([{ number: 3, mergedBy: nil }]))

      expect(service.merged_pull_requests('owner/app')[:nodes]).to eq([{ number: 3, merged_by: nil }])
    end
  end

  describe '#each_pull_request' do
    it 'walks in the order pull requests were opened, so none shifts pages mid-walk' do
      allow(octokit_client).to receive(:pull_requests).and_return([])

      service.each_pull_request('owner/repo') { |_pr| nil }

      expect(octokit_client).to have_received(:pull_requests)
        .with('owner/repo', hash_including(sort: 'created', direction: 'asc'))
    end

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

  describe '#issue_events' do
    it 'keeps the events of every page, not only the last' do
      pages = [Array.new(99) { double(event: 'labeled') } + [double(event: 'merged')],
               [double(event: 'ready_for_review')]]
      allow(octokit_client).to receive(:issue_events) { |_repo, _number, options| pages[options[:page] - 1] || [] }

      events = service.send(:issue_events, 'owner/repo', 123)

      expect(events.size).to be(101)
      expect(events.map(&:event)).to include('merged', 'ready_for_review')
    end

    it 'asks for the largest page GitHub serves' do
      allow(octokit_client).to receive(:issue_events).and_return([])

      service.send(:issue_events, 'owner/repo', 123)

      expect(octokit_client).to have_received(:issue_events).with('owner/repo', 123, hash_including(per_page: 100))
    end
  end

  describe '#ready_for_review_time' do
    it 'reads the moment the pull request left draft' do
      ready_event = double(event: 'ready_for_review', created_at: 2.days.ago)
      events = [double(event: 'labeled', created_at: 1.day.ago), ready_event]

      expect(service.send(:ready_for_review_time, events, 3.days.ago)).to eq(ready_event.created_at)
    end

    it 'falls back to when it was opened, for one opened ready for review' do
      created_time = 3.days.ago
      events = [double(event: 'labeled', created_at: 1.day.ago)]

      expect(service.send(:ready_for_review_time, events, created_time)).to eq(created_time)
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
      expect(service).to have_received(:sleep).exactly(GithubRateLimiting::MAX_RETRIES).times
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
