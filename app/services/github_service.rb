class GithubService
  include GithubRateLimiting

  def initialize(access_token)
    @client = Octokit::Client.new(access_token: access_token)
    @client.auto_paginate = false
  end

  def get_pull_request_count(repo_name)
    # Get total count of PRs for progress tracking
    # Using search API which returns total_count
    with_rate_limit_handling do
      result = @client.search_issues("repo:#{repo_name} is:pr", per_page: 1)
      result.total_count
    end
  rescue StandardError => e
    Rails.logger.warn "Could not get PR count: #{e.message}"
    nil
  end

  def default_branch(repo_name)
    with_rate_limit_handling { @client.repository(repo_name).default_branch }
  end

  MERGED_PULL_REQUESTS_QUERY = <<~GRAPHQL.freeze
    query($owner: String!, $name: String!, $after: String) {
      repository(owner: $owner, name: $name) {
        pullRequests(states: MERGED, first: 100, after: $after) {
          pageInfo { hasNextPage endCursor }
          nodes { number mergedBy { login __typename ... on User { databaseId } ... on Bot { databaseId } } }
        }
      }
    }
  GRAPHQL

  # One page of merged pull requests and their mergers, 100 at a time, as
  # {nodes: [{number:, merged_by:}], has_next_page:, end_cursor:}. GitHub's
  # REST endpoints answer with a merger one pull request at a time, which is
  # thousands of calls on a repository of any age.
  def merged_pull_requests(repo_name, after: nil)
    owner, name = repo_name.split('/')
    page = with_rate_limit_handling do
      response = @client.post('/graphql', { query: MERGED_PULL_REQUESTS_QUERY,
                                            variables: { owner: owner, name: name, after: after } }.to_json)
      merged_pull_requests_from(response, repo_name)
    end

    { nodes: page.nodes.map { |node| merged_pull_request(node) },
      has_next_page: page.pageInfo.hasNextPage,
      end_cursor: page.pageInfo.endCursor }
  end

  # Yields every pull request GitHub lists for the repository, open or closed,
  # oldest first: in the sync's updated-first order a pull request updated
  # during the walk moves to page one and pushes another off the page behind it.
  def each_pull_request(repo_name, &)
    page = 1
    loop do
      pull_requests = fetch_pull_requests_page(repo_name, page, order: { sort: 'created', direction: 'asc' })
      break if pull_requests.empty?

      pull_requests.each(&)
      page += 1
    end
  end

  # The processor is called with each pull request's GitHub data once it is
  # stored; it owns week associations and statistics.
  def fetch_and_store_pull_requests(repo_name, processor:, fetch_all: false)
    repository = Repository.find_by!(name: repo_name)
    last_fetched_at = fetch_all ? nil : repository.last_fetched_at&.iso8601

    page = 1
    total_processed = 0
    most_recent_update = nil

    loop do
      pull_requests = fetch_pull_requests_page(repo_name, page, since: last_fetched_at)
      break if pull_requests.empty?

      new_prs = pull_requests.reject { |pr| pr.updated_at <= repository.last_fetched_at } if last_fetched_at

      break if new_prs&.empty?

      (new_prs || pull_requests).each do |pr|
        process_pull_request(repository, repo_name, pr)
        most_recent_update = [most_recent_update, pr.updated_at].compact.max
        Rails.logger.debug { "Processed PR ##{pr.number}" }
        total_processed += 1

        processor.call(pr)
      end

      page += 1
    end

    repository.update!(last_fetched_at: most_recent_update) if most_recent_update

    Rails.logger.info "Processed #{total_processed} pull requests for #{repo_name}"
    Rails.logger.info "Most recent update: #{most_recent_update}"
  end

  def fetch_recent_review_activity(repo_name, since_date = nil)
    repository = Repository.find_by(name: repo_name)
    return unless repository

    # Use since_date or fall back to last_fetched_at or 7 days ago
    since = since_date || repository.last_fetched_at || 7.days.ago

    Rails.logger.info "Fetching recent review activity for #{repo_name} since #{since}"

    # Fetch review comments across the repository using GitHub API
    # GET /repos/{owner}/{repo}/pulls/comments?since=date&sort=created&direction=desc
    page = 1
    per_page = 100
    total_processed = 0
    affected_prs = Set.new

    loop do
      review_comments = fetch_review_comments_page(repo_name, page, per_page, since)
      break if review_comments.empty?

      review_comments.each do |comment|
        # Each comment belongs to a PR - find and update that PR's reviews
        pr_number = comment.pull_request_url.split('/').last.to_i
        pull_request = repository.pull_requests.find_by(number: pr_number)

        next unless pull_request

        # Re-fetch reviews for this PR to get the latest review data
        fetch_and_store_reviews(pull_request, repo_name, pr_number)
        affected_prs << pull_request
        total_processed += 1

        Rails.logger.debug { "Updated reviews for PR ##{pr_number} due to comment activity" }
      end

      page += 1

      # Safety break to avoid infinite loops
      break if page > 50 # Max 5000 comments
    end

    Rails.logger.info "Processed #{total_processed} review comments affecting #{affected_prs.size} PRs"

    # Update week associations for affected PRs
    affected_prs.each do |pr|
      pr.ensure_weeks_exist_and_update_associations
    end

    total_processed
  end

  private

  # GitHub answers a GraphQL failure with a 200 and an errors array, so the
  # response has to be read before its data is trusted. A rate-limited query
  # arrives the same way, and is raised as the error the retry logic waits on.
  def merged_pull_requests_from(response, repo_name)
    errors = Array(response.errors)
    raise GithubRateLimiting::RateLimited if errors.any? { |error| error.type == 'RATE_LIMITED' }

    raise "GitHub rejected the query for #{repo_name}: #{errors.map(&:message).join('; ')}" if errors.any?

    repository = response.data&.repository
    raise "GitHub returned no repository named #{repo_name}; is it visible to this token?" unless repository

    repository.pullRequests
  end

  def merged_pull_request(node)
    merger = node.mergedBy
    merged_by = { login: merger.login, id: merger.databaseId, type: merger.__typename } if merger
    { number: node.number, merged_by: merged_by }
  end

  def fetch_pull_requests_page(repo_name, page, since: nil, order: { sort: 'updated', direction: 'desc' })
    options = { state: 'all', page: page, per_page: 100 }.merge(order)
    options[:since] = since if since

    with_rate_limit_handling do
      @client.pull_requests(repo_name, options)
    end
  end

  def fetch_review_comments_page(repo_name, page, per_page, since = nil)
    options = {
      page: page,
      per_page: per_page,
      sort: 'created',
      direction: 'desc'
    }
    options[:since] = since.iso8601 if since

    with_rate_limit_handling do
      @client.pull_requests_comments(repo_name, options)
    end
  end

  # GitHub serves a pull request's events oldest first, 30 to a page by
  # default, so the events this sync reads -- ready_for_review, and the merge
  # -- are the ones a busy pull request pushes off the first page.
  def issue_events(repo_name, pr_number)
    events = []
    page = 1
    loop do
      batch = with_rate_limit_handling do
        @client.issue_events(repo_name, pr_number, page: page, per_page: 100)
      end
      events.concat(batch)
      break if batch.size < 100

      page += 1
    end
    events
  end

  # A pull request opened ready for review has no ready_for_review event
  def ready_for_review_time(events, created_at)
    events.find { |event| event.event == 'ready_for_review' }&.created_at || created_at
  end

  # GitHub's merge event names whoever pressed Merge, which is the actor that
  # enabled auto-merge when the merge came from the queue.
  def merger_of(events)
    actor = events.find { |event| event.event == 'merged' }&.actor
    find_or_create_contributor(actor) if actor
  end

  def process_pull_request(repository, repo_name, pr)
    pull_request = repository.pull_requests.find_or_initialize_by(number: pr.number)
    author = Contributor.find_or_create_from_github(pr.user)
    events = pr.draft && pr.merged_at.nil? ? [] : issue_events(repo_name, pr.number)
    ready_for_review_at = pr.draft ? nil : ready_for_review_time(events, pr.created_at)

    pull_request.update!(
      title: pr.title,
      state: pr.state,
      draft: pr.draft,
      author: author,
      gh_created_at: pr.created_at,
      gh_updated_at: pr.updated_at,
      gh_merged_at: pr.merged_at,
      gh_closed_at: pr.closed_at,
      ready_for_review_at: ready_for_review_at,
      base_ref: pr.base.ref,
      head_ref: pr.head.ref,
      head_repository: pr.head.repo&.full_name,
      merged_by: (merger_of(events) if pr.merged_at)
    )

    fetch_and_store_reviews(pull_request, repo_name, pr.number)
    store_author(pull_request, pr)
  end

  def fetch_and_store_reviews(pull_request, repo_name, pr_number)
    reviews = with_rate_limit_handling do
      @client.pull_request_reviews(repo_name, pr_number)
    end

    # Store all reviews regardless of timing - we'll filter when calculating metrics
    reviews.each do |review|
      next if review.submitted_at.nil?

      author = find_or_create_contributor(review.user)
      review_record = pull_request.reviews.find_or_initialize_by(
        state: review.state,
        submitted_at: review.submitted_at,
        author: author
      )
      review_record.save!
    end
  end

  def find_or_create_contributor(github_user)
    # For API responses that have full data including github_id
    if github_user.respond_to?(:id) && github_user.id
      Contributor.find_or_create_from_github(github_user)
    else
      # Fallback for cases where we only have username
      Contributor.find_or_create_from_username(github_user.login, {
                                                 name: github_user.respond_to?(:name) ? github_user.name : nil,
                                                 email: github_user.respond_to?(:email) ? github_user.email : nil
                                               })
    end
  end

  def store_user(pull_request, github_user, role)
    return unless github_user

    contributor = find_or_create_contributor(github_user)

    PullRequestUser.find_or_create_by(
      pull_request: pull_request,
      user: contributor,
      role: role
    )
  end

  # The author's participation row, which the contributor pages read. The
  # merger lives on the pull request itself; GitHub's list payload, the only
  # place this ever looked for one, does not carry it.
  def store_author(pull_request, pr)
    store_user(pull_request, pr.user, 'author')
  end
end
