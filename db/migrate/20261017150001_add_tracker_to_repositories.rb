class AddTrackerToRepositories < ActiveRecord::Migration[7.2]
  def change
    add_reference :repositories, :tracker, foreign_key: true
  end
end
