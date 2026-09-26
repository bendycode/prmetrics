class AddApprovalToWeeks < ActiveRecord::Migration[7.2]
  def change
    add_reference :pull_requests, :first_approval_week, foreign_key: { to_table: :weeks }

    add_column :weeks, :num_prs_approved, :integer, default: 0, null: false,
                                                    comment: 'Cached count of pull requests first cleared to merge ' \
                                                             'during the week: approved by a person, or merged by ' \
                                                             'their own author'
    add_column :weeks, :avg_hrs_to_approval, :decimal, precision: 10, scale: 2
  end
end
