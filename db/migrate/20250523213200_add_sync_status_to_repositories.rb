class AddSyncStatusToRepositories < ActiveRecord::Migration[7.1]
  def change
    add_column :repositories, :sync_status, :string
    add_column :repositories, :sync_started_at, :datetime
    add_column :repositories, :sync_completed_at, :datetime
    add_column :repositories, :last_sync_error, :text
  end
end
