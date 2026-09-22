class AddMergedByToPullRequests < ActiveRecord::Migration[7.2]
  def change
    add_reference :pull_requests, :merged_by, foreign_key: { to_table: :contributors }
    add_column :contributors, :bot, :boolean, default: false, null: false
  end
end
