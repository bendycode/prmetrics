class GithubService
  def initialize(access_token)
    @client = Octokit::Client.new(access_token: access_token)
    @client.auto_paginate = false  # We'll handle pagination manually
  end

  def fetch_and_store_pull_requests(repo_name)
    repository = Repository.find_or_create_by(name: repo_name)
    page = 1
    per_page = 100

    loop do
      pull_requests = fetch_pull_requests_page(repo_name, page, per_page)
      break if pull_requests.empty?

      pull_requests.each do |pr|
        process_pull_request(repository, repo_name, pr)
        print '.'
        $stdout.flush
      end

      page += 1
    end
    puts
  end

  private

  def fetch_pull_requests_page(repo_name, page, per_page)
    @client.pull_requests(repo_name, state: 'all', page: page, per_page: per_page)
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
      pull_request.reviews.find_or_create_by(
        state: review.state,
        submitted_at: review.submitted_at
      )
    end
  end

  def fetch_and_store_users(pull_request, pr)
    store_user(pull_request, pr.user, 'author')
    store_user(pull_request, pr.merged_by, 'merger') if pr.merged_by
  end

  def store_user(pull_request, github_user, role)
    return unless github_user

    user = User.find_or_create_by(username: github_user.login) do |u|
      u.name = github_user.name
      u.email = github_user.email
    end

    PullRequestUser.find_or_create_by(
      pull_request: pull_request,
      user: user,
      role: role
    )
  end
end
