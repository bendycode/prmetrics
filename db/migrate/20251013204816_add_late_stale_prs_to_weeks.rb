class AddLateStalePrsToWeeks < ActiveRecord::Migration[7.1]
  def up
    add_column :weeks, :num_prs_late, :integer, default: 0, null: false,
      comment: 'Cached count of PRs approved > 1 week and < 4 weeks ago (8-27 days)'
    add_column :weeks, :num_prs_stale, :integer, default: 0, null: false,
      comment: 'Cached count of PRs approved ≥ 4 weeks ago (28+ days)'
  end

  def down
    remove_column :weeks, :num_prs_stale if column_exists?(:weeks, :num_prs_stale)
    remove_column :weeks, :num_prs_late if column_exists?(:weeks, :num_prs_late)
  end
end
