class AddReadyForReviewAtToPullRequests < ActiveRecord::Migration[7.1]
  def change
    add_column :pull_requests, :ready_for_review_at, :datetime
  end
end
