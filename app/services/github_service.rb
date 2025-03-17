class GithubService
  MAX_RETRIES = 5

  def initialize(access_token)
    @client = Octokit::Client.new(access_token: access_token)
    @client.auto_paginate = false
  end

  def fetch_and_store_pull_requests(repo_name, fetch_all: false)
    repository = Repository.find_or_create_by(name: repo_name)
    last_fetched_at = fetch_all ? nil : repository.last_fetched_at&.iso8601

    page = 1
    per_page = 100
    total_processed = 0
    most_recent_update = nil

    loop do
      pull_requests = fetch_pull_requests_page(repo_name, page, per_page, last_fetched_at)
      break if pull_requests.empty?

      new_prs = pull_requests.reject { |pr| pr.updated_at <= repository.last_fetched_at } if last_fetched_at

      break if new_prs&.empty?

      (new_prs || pull_requests).each do |pr|
        process_pull_request(repository, repo_name, pr)
        most_recent_update = [most_recent_update, pr.updated_at].compact.max
        print '.'
        $stdout.flush
        total_processed += 1
      end

      page += 1
    end

    WeekStatsService.update_all_weeks

    if most_recent_update
      repository.update(last_fetched_at: most_recent_update)
    end

    puts "\nProcessed #{total_processed} pull requests."
    puts "Most recent update: #{most_recent_update}"
  end

  private

  def fetch_pull_requests_page(repo_name, page, per_page, since = nil)
    options = {
      state: 'all',
      page: page,
      per_page: per_page,
      sort: 'updated',
      direction: 'desc'
    }
    options[:since] = since if since

    with_rate_limit_handling do
      @client.pull_requests(repo_name, options)
    end
  end

  def determine_ready_for_review_at(repo_name, pr_number, created_at)
    events = with_rate_limit_handling do
      @client.issue_events(repo_name, pr_number)
    end
    ready_for_review_event = events.find { |e| e.event == 'ready_for_review' }

    if ready_for_review_event
      ready_for_review_event.created_at
    else
      created_at # If no 'ready_for_review' event, assume it was ready at creation
    end
  end

  def process_pull_request(repository, repo_name, pr)
    pull_request = repository.pull_requests.find_or_initialize_by(number: pr.number)
    author = find_or_create_github_user(pr.user)
    ready_for_review_at = pr.draft ? nil : determine_ready_for_review_at(repo_name, pr.number, pr.created_at)

    pull_request.update(
      title: pr.title,
      state: pr.state,
      draft: pr.draft,
      author: author,
      gh_created_at: pr.created_at,
      gh_updated_at: pr.updated_at,
      gh_merged_at: pr.merged_at,
      gh_closed_at: pr.closed_at,
      ready_for_review_at: ready_for_review_at
    )

    fetch_and_store_reviews(pull_request, repo_name, pr.number)
    fetch_and_store_users(pull_request, pr)
    pull_request.update_week_associations
  end

  def find_or_create_github_user(github_user)
    GithubUser.find_or_create_by!(github_id: github_user.id.to_s) do |user|
     user.username = github_user.login
     user.name = github_user.name
     user.avatar_url = github_user.avatar_url
    end
  end

  def fetch_and_store_reviews(pull_request, repo_name, pr_number)
    reviews = with_rate_limit_handling do
      @client.pull_request_reviews(repo_name, pr_number)
    end

    # Store all reviews regardless of timing - we'll filter when calculating metrics
    reviews.each do |review|
      next if review.submitted_at.nil?

      author = find_or_create_user(review.user)
      review_record = pull_request.reviews.find_or_initialize_by(
        state: review.state,
        submitted_at: review.submitted_at
      )
      review_record.author = author
      review_record.save!
    end
  end

  def find_or_create_user(github_user)
    User.find_or_create_by(username: github_user.login) do |u|
      u.name = github_user.name
      u.email = github_user.email
    end
  end

  def store_user(pull_request, github_user, role)
    return unless github_user

    user = find_or_create_user(github_user)

    PullRequestUser.find_or_create_by(
      pull_request: pull_request,
      user: user,
      role: role
    )
  end

  def fetch_and_store_users(pull_request, pr)
    store_user(pull_request, pr.user, 'author')
    store_user(pull_request, pr.merged_by, 'merger') if pr.merged_by
  end

  def with_rate_limit_handling
    retries = 0
    begin
      yield
    rescue Octokit::TooManyRequests => e
      if retries < MAX_RETRIES
        wait_time = calculate_wait_time(e.response_headers, retries)
        puts "\nRate limit exceeded. Waiting for #{wait_time} seconds before retrying..."
        sleep(wait_time)
        retries += 1
        retry
      else
        raise "Max retries reached. Unable to complete the request due to rate limiting."
      end
    rescue Faraday::ConnectionFailed, Net::OpenTimeout => e
      if retries < MAX_RETRIES
        wait_time = 5 * (2 ** retries) # exponential backoff
        puts "\nConnection error: #{e.message}. Retrying in #{wait_time} seconds..."
        sleep(wait_time)
        retries += 1
        retry
      else
        raise "Max retries reached. Unable to complete the request due to connection issues."
      end
    end
  end

  def calculate_wait_time(headers, retry_count)
    if headers['retry-after']
      headers['retry-after'].to_i
    elsif headers['x-ratelimit-remaining'].to_i == 0
      reset_time = Time.at(headers['x-ratelimit-reset'].to_i)
      [reset_time - Time.now, 0].max
    else
      60 * (2 ** retry_count) # exponential backoff starting at 1 minute
    end
  end
end
