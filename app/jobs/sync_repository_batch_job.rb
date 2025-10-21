class SyncRepositoryBatchJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 100

  def perform(repository_name, page: 1, fetch_all: false)
    repository = Repository.find_by!(name: repository_name)

    # Mark as in progress on first page
    if page == 1
      repository.update!(
        sync_status: 'in_progress',
        sync_started_at: Time.current,
        last_sync_error: nil
      )
    end

    service = GithubService.new(ENV.fetch('GITHUB_ACCESS_TOKEN', nil))

    # Fetch one page of PRs
    pull_requests = fetch_pull_requests_page(service, repository, page)

    if pull_requests.empty?
      # We've reached the end
      finalize_sync(repository)
    else
      # Process this batch
      process_pull_requests(service, repository, pull_requests)

      # Update progress
      update_progress(repository, page, pull_requests.size)

      # Check if we should continue
      if should_continue_fetching?(repository, pull_requests, fetch_all)
        # Queue next page
        SyncRepositoryBatchJob.perform_later(repository_name, page: page + 1, fetch_all: fetch_all)
      else
        finalize_sync(repository)
      end
    end
  rescue => e
    handle_sync_error(repository, e)
    raise # Re-raise to trigger Sidekiq retry
  end

  private

  def fetch_pull_requests_page(service, repository, page)
    # We need to directly use Octokit since GithubService doesn't expose the client
    client = Octokit::Client.new(access_token: ENV.fetch('GITHUB_ACCESS_TOKEN', nil))
    client.pull_requests(
      repository.name,
      state: 'all',
      per_page: BATCH_SIZE,
      page: page,
      sort: 'updated',
      direction: 'desc'
    )
  end

  def process_pull_requests(service, repository, pull_requests)
    # For now, we'll use the existing GithubService logic by calling the full method
    # This is inefficient but works until we refactor GithubService
    pull_requests.each do |pr_data|
      # Recreate the processing logic from GithubService
      process_single_pull_request(repository, pr_data)
    end
  end

  def process_single_pull_request(repository, pr_data)
    # Handle both Octokit objects and hashes
    pr_number = pr_data.respond_to?(:number) ? pr_data.number : pr_data[:number]

    pull_request = repository.pull_requests.find_or_initialize_by(number: pr_number)

    # Create/update author using proper GitHub integration
    user_data = pr_data.respond_to?(:user) ? pr_data.user : pr_data[:user]
    github_user = nil
    if user_data
      github_user = find_or_create_contributor(user_data)
    end

    # Determine proper ready_for_review_at using GitHub events
    draft_status = pr_data.respond_to?(:draft) ? pr_data.draft : pr_data[:draft]
    created_at = pr_data.respond_to?(:created_at) ? pr_data.created_at : pr_data[:created_at]
    ready_for_review_at = draft_status ? nil : determine_ready_for_review_at(repository.name, pr_number, created_at)

    pull_request.assign_attributes(
      title: pr_data.respond_to?(:title) ? pr_data.title : pr_data[:title],
      state: pr_data.respond_to?(:state) ? pr_data.state : pr_data[:state],
      draft: draft_status,
      gh_created_at: created_at,
      gh_updated_at: pr_data.respond_to?(:updated_at) ? pr_data.updated_at : pr_data[:updated_at],
      gh_closed_at: pr_data.respond_to?(:closed_at) ? pr_data.closed_at : pr_data[:closed_at],
      gh_merged_at: pr_data.respond_to?(:merged_at) ? pr_data.merged_at : pr_data[:merged_at],
      ready_for_review_at: ready_for_review_at,
      author: github_user
    )

    pull_request.save!

    # Fetch and store reviews for this PR
    fetch_and_store_reviews(pull_request, repository.name, pr_number)

    # Fetch and store user associations
    fetch_and_store_users(pull_request, pr_data)

    # Update week associations
    pull_request.ensure_weeks_exist_and_update_associations
  end

  def update_progress(repository, page, batch_size)
    total_processed = ((page - 1) * BATCH_SIZE) + batch_size
    Rails.logger.info "Processed page #{page} for #{repository.name} (#{total_processed} PRs so far)"

    # Optionally store progress
    repository.update_column(:sync_progress, total_processed)
  end

  def should_continue_fetching?(repository, pull_requests, fetch_all)
    return false if pull_requests.size < BATCH_SIZE # Last page

    if fetch_all
      true
    else
      # Check if we've hit PRs we've already seen
      oldest_pr_date = pull_requests.last.updated_at
      repository.last_fetched_at.nil? || oldest_pr_date > repository.last_fetched_at
    end
  end

  def finalize_sync(repository)
    repository.update!(
      sync_status: 'completed',
      sync_completed_at: Time.current,
      last_fetched_at: Time.current
    )

    # Queue stats calculation
    UpdateRepositoryStatsJob.perform_later(repository.id)

    Rails.logger.info "Completed sync for #{repository.name}"
  end

  def handle_sync_error(repository, error)
    repository.update!(
      sync_status: 'failed',
      last_sync_error: error.message
    )
    Rails.logger.error "Sync failed for #{repository.name}: #{error.message}"
  end

  def determine_ready_for_review_at(repo_name, pr_number, created_at)
    events = with_rate_limit_handling do
      client = Octokit::Client.new(access_token: ENV.fetch('GITHUB_ACCESS_TOKEN', nil))
      client.issue_events(repo_name, pr_number)
    end
    ready_for_review_event = events.find { |e| e.event == 'ready_for_review' }

    if ready_for_review_event
      ready_for_review_event.created_at
    else
      created_at # If no 'ready_for_review' event, assume it was ready at creation
    end
  end

  def fetch_and_store_reviews(pull_request, repo_name, pr_number)
    reviews = with_rate_limit_handling do
      client = Octokit::Client.new(access_token: ENV.fetch('GITHUB_ACCESS_TOKEN', nil))
      client.pull_request_reviews(repo_name, pr_number)
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
    # Handle both Hash and object formats
    user_id = github_user.respond_to?(:id) ? github_user.id : github_user[:id]
    user_login = github_user.respond_to?(:login) ? github_user.login : github_user[:login]
    user_name = github_user.respond_to?(:name) ? github_user.name : github_user[:name]
    user_email = github_user.respond_to?(:email) ? github_user.email : github_user[:email]

    # For API responses that have full data including github_id
    if user_id
      if github_user.respond_to?(:id)
        # Object format - can use existing method
        Contributor.find_or_create_from_github(github_user)
      else
        # Hash format - need to handle manually
        Contributor.find_or_create_by(github_id: user_id.to_s) do |c|
          c.username = user_login
          c.name = user_name
          c.avatar_url = github_user.respond_to?(:avatar_url) ? github_user.avatar_url : github_user[:avatar_url]
        end
      end
    else
      # Fallback for cases where we only have username
      Contributor.find_or_create_from_username(user_login, {
                                                 name: user_name,
                                                 email: user_email
                                               })
    end
  end

  def fetch_and_store_users(pull_request, pr_data)
    # Store author
    user_data = pr_data.respond_to?(:user) ? pr_data.user : pr_data[:user]
    store_user(pull_request, user_data, 'author') if user_data

    # Store merger if present
    merger_data = pr_data.respond_to?(:merged_by) ? pr_data.merged_by : pr_data[:merged_by]
    store_user(pull_request, merger_data, 'merger') if merger_data
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

  def with_rate_limit_handling
    retries = 0
    begin
      yield
    rescue Octokit::TooManyRequests => e
      raise "Max retries reached. Unable to complete the request due to rate limiting." unless retries < 5

      wait_time = calculate_wait_time(e.response_headers, retries)
      Rails.logger.warn "Rate limit exceeded. Waiting for #{wait_time} seconds before retrying..."
      sleep(wait_time)
      retries += 1
      retry
    rescue Faraday::ConnectionFailed, Net::OpenTimeout => e
      Rails.logger.warn "ConnectionFailed or OpenTimeout error caught. retries: #{retries}"
      raise "Max retries reached. Unable to complete the request due to connection issues." unless retries < 5

      wait_time = 5 * (2**retries) # exponential backoff
      Rails.logger.warn "Connection error: #{e.message}. Retrying in #{wait_time} seconds..."
      sleep(wait_time)
      retries += 1
      retry
    end
  end

  def calculate_wait_time(headers, retry_count)
    if headers.nil?
      return exponential_backoff_starting_at_one_minute retry_count
    end

    if headers['retry-after']
      headers['retry-after'].to_i
    elsif headers['x-ratelimit-remaining'].to_i == 0 && headers['x-ratelimit-reset']
      reset_time = Time.at(headers['x-ratelimit-reset'].to_i)
      wait_time = [reset_time - Time.now, 0].max

      # If we're still hitting rate limits and wait time is 0,
      # use exponential backoff instead
      if wait_time == 0
        wait_time = exponential_backoff_starting_at_one_minute retry_count
      end

      wait_time
    else
      exponential_backoff_starting_at_one_minute retry_count
    end
  end

  def exponential_backoff_starting_at_one_minute retry_count
    60 * (2**retry_count)
  end
end
