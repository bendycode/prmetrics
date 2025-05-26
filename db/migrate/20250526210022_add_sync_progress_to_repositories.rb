class AddSyncProgressToRepositories < ActiveRecord::Migration[7.1]
  def change
    add_column :repositories, :sync_progress, :integer
  end
end
