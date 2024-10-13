class AddLastFetchedAtToRepositories < ActiveRecord::Migration[7.1]
  def change
    add_column :repositories, :last_fetched_at, :datetime
  end
end
