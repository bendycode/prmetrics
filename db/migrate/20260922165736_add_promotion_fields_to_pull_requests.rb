class AddPromotionFieldsToPullRequests < ActiveRecord::Migration[7.2]
  def change
    add_column :pull_requests, :base_ref, :string
    add_column :pull_requests, :head_ref, :string
    # GitHub's owner/name for the head branch's repository: a fork's main is not ours
    add_column :pull_requests, :head_repository, :string
    add_column :pull_requests, :promotion, :boolean, default: false, null: false
    add_index :pull_requests, :repository_id, where: 'promotion', name: 'index_pull_requests_promotions'

    add_column :repositories, :default_branch, :string
  end
end
