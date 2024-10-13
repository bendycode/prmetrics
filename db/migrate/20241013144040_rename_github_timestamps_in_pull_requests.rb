class RenameGithubTimestampsInPullRequests < ActiveRecord::Migration[7.1]
  def change
    rename_column :pull_requests, :created_at, :gh_created_at
    rename_column :pull_requests, :updated_at, :gh_updated_at
    rename_column :pull_requests, :merged_at, :gh_merged_at
    rename_column :pull_requests, :closed_at, :gh_closed_at

    # Add Rails timestamps
    add_column :pull_requests, :created_at, :datetime
    add_column :pull_requests, :updated_at, :datetime
  end
end
