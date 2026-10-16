class AddListedAtToPullRequests < ActiveRecord::Migration[7.2]
  def change
    add_column :pull_requests, :listed_at, :datetime
  end
end
