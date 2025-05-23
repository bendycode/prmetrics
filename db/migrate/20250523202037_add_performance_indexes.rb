class AddPerformanceIndexes < ActiveRecord::Migration[7.1]
  def change
    # Critical indexes for common queries identified by benchmark
    
    # Pull requests - most important indexes
    add_index :pull_requests, [:repository_id, :number], name: 'idx_pull_requests_repo_number'
    add_index :pull_requests, [:repository_id, :state, :draft], name: 'idx_pull_requests_repo_state_draft'
    add_index :pull_requests, :gh_created_at, name: 'idx_pull_requests_gh_created'
    add_index :pull_requests, :gh_merged_at, name: 'idx_pull_requests_gh_merged'
    add_index :pull_requests, :gh_closed_at, name: 'idx_pull_requests_gh_closed'
    add_index :pull_requests, :ready_for_review_at, name: 'idx_pull_requests_ready_for_review'
    
    # Reviews - for ordering and filtering
    add_index :reviews, :submitted_at, name: 'idx_reviews_submitted_at'
    add_index :reviews, [:pull_request_id, :submitted_at], name: 'idx_reviews_pr_submitted'
    
    # Weeks - for date range queries
    add_index :weeks, [:repository_id, :begin_date, :end_date], name: 'idx_weeks_repo_dates'
    add_index :weeks, [:begin_date, :end_date], name: 'idx_weeks_dates'
    
    # Pull request users - for role-based queries
    add_index :pull_request_users, [:pull_request_id, :role], name: 'idx_pr_users_pr_role'
    add_index :pull_request_users, [:user_id, :role], name: 'idx_pr_users_user_role'
    
    # Users and repositories - for lookups
    add_index :users, :username, name: 'idx_users_username'
    add_index :repositories, :name, name: 'idx_repositories_name'
  end
end