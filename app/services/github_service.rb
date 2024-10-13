class GithubService
  def initialize(access_token)
    @client = Octokit::Client.new(access_token: access_token)
    @client.auto_paginate = true
  end

  def fetch_and_store_pull_requests(repo_name)
    repository = Repository.find_or_create_by(name: repo_name)
    pull_requests = @client.pull_requests(repo_name, state: 'all')

    pull_requests.each do |pr|
      pull_request = repository.pull_requests.find_or_initialize_by(number: pr.number)
      pull_request.update(
        title: pr.title,
        state: pr.state,
        draft: pr.draft,
        gh_created_at: pr.created_at,
        gh_updated_at: pr.updated_at,
        gh_merged_at: pr.merged_at,
        gh_closed_at: pr.closed_at
      )

      fetch_and_store_reviews(pull_request, repo_name, pr.number)
      fetch_and_store_users(pull_request, pr)
    end
  end

  private

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
