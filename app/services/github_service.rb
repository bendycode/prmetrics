class GithubService
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

    @client.pull_requests(repo_name, options)
  rescue Octokit::TooManyRequests => e
    puts "\nRate limit exceeded. Waiting for reset..."
    sleep(e.rate_limit.resets_in + 1)
    retry
  rescue Faraday::ConnectionFailed, Net::OpenTimeout => e
    puts "\nConnection error: #{e.message}. Retrying in 5 seconds..."
    sleep(5)
    retry
  end

  def process_pull_request(repository, repo_name, pr)
    pull_request = repository.pull_requests.find_or_initialize_by(number: pr.number)

    ready_for_review_at = pr.draft ? nil : determine_ready_for_review_at(repo_name, pr.number, pr.created_at)

    pull_request.update(
      title: pr.title,
      state: pr.state,
      draft: pr.draft,
      gh_created_at: pr.created_at,
      gh_updated_at: pr.updated_at,
      gh_merged_at: pr.merged_at,
      gh_closed_at: pr.closed_at,
      ready_for_review_at: ready_for_review_at
    )

    fetch_and_store_reviews(pull_request, repo_name, pr.number)
    fetch_and_store_users(pull_request, pr)
  end

  def determine_ready_for_review_at(repo_name, pr_number, created_at)
    events = @client.issue_events(repo_name, pr_number)
    ready_for_review_event = events.find { |e| e.event == 'ready_for_review' }

    if ready_for_review_event
      ready_for_review_event.created_at
    else
      created_at # If no 'ready_for_review' event, assume it was ready at creation
    end
  end

  def fetch_and_store_reviews(pull_request, repo_name, pr_number)
    reviews = @client.pull_request_reviews(repo_name, pr_number)
    reviews.each do |review|
      author = find_or_create_user(review.user)
      pull_request.reviews.find_or_create_by(
        state: review.state,
        submitted_at: review.submitted_at
      ) do |r|
        r.author = author
      end
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
end
