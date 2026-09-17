# The page table for spec/requests/ungranted_repository_leak_spec.rb.
module UngrantedRepositoryLeakPages
  MARKER = 'leakmarker'.freeze

  PAGES = {
    'root' => ->(_) { '/' },
    'dashboard' => ->(_) { '/dashboard' },
    'dashboard filtered to the ungranted repository' => ->(r) { "/dashboard?repository_id=#{r[:hidden_repository].id}" },
    'health' => ->(_) { '/health' },
    'edit_account' => ->(_) { '/account/edit' },
    'users' => ->(_) { '/users' },
    'new_user' => ->(_) { '/users/new' },
    'repositories' => ->(_) { '/repositories' },
    'new_repository' => ->(_) { '/repositories/new' },
    'repository' => ->(r) { "/repositories/#{r[:repository].id}" },
    'repository_pull_requests' => ->(r) { "/repositories/#{r[:repository].id}/pull_requests" },
    'repository_week' => ->(r) { "/repositories/#{r[:repository].id}/weeks/#{r[:week].id}" },
    'pr_list_repository_week' => lambda { |r|
      %w[started open first_reviewed late stale merged cancelled draft].map do |category|
        "/repositories/#{r[:repository].id}/weeks/#{r[:week].id}/pr_list?category=#{category}"
      end
    },
    'pull_request' => ->(r) { "/pull_requests/#{r[:pull_request].id}" },
    'pull_request_reviews' => ->(r) { "/pull_requests/#{r[:pull_request].id}/reviews" },
    'pull_request_pull_request_users' => ->(r) { "/pull_requests/#{r[:pull_request].id}/pull_request_users" },
    'review' => ->(r) { "/reviews/#{r[:review].id}" },
    'pull_request_user' => ->(r) { "/pull_request_users/#{r[:pull_request_user].id}" },
    'contributors' => ->(_) { '/contributors' },
    'contributor' => ->(r) { "/contributors/#{r[:shared_contributor].id}" }
  }.freeze

  # Every other page must render for the regular user, so a redirect cannot
  # pass for the wrong reason. These three are admin-only, and the health
  # check reports on services the test environment does not run.
  PAGES_NOT_RENDERED_FOR_REGULAR_USERS = %w[users new_user new_repository health].freeze

  # Framework and Devise controllers render no repository data.
  FRAMEWORK_CONTROLLER_PREFIXES = %w[devise/ rails/ turbo/ active_storage/ action_mailbox/].freeze
end
