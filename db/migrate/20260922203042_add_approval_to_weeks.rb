class AddApprovalToWeeks < ActiveRecord::Migration[7.2]
  def change
    add_reference :pull_requests, :first_approval_week, foreign_key: { to_table: :weeks }

    add_column :weeks, :num_prs_approved, :integer, default: 0, null: false,
                                                    comment: 'Cached count of PRs first approved during the week'
    add_column :weeks, :avg_hrs_to_approval, :decimal, precision: 10, scale: 2
  end
end
