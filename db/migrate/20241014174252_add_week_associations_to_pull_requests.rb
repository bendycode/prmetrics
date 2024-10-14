class AddWeekAssociationsToPullRequests < ActiveRecord::Migration[7.1]
  def change
    add_reference :pull_requests, :ready_for_review_week, foreign_key: { to_table: :weeks }
    add_reference :pull_requests, :first_review_week, foreign_key: { to_table: :weeks }
    add_reference :pull_requests, :merged_week, foreign_key: { to_table: :weeks }
    add_reference :pull_requests, :closed_week, foreign_key: { to_table: :weeks }
  end
end
