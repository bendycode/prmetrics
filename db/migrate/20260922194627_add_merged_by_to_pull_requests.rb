class AddMergedByToPullRequests < ActiveRecord::Migration[7.2]
  def up
    add_reference :pull_requests, :merged_by, foreign_key: { to_table: :contributors }
    add_column :contributors, :bot, :boolean, default: false, null: false

    # GitHub Apps' logins all end this way; the sync replaces it with the
    # account type GitHub reports as each contributor is seen again.
    Contributor.where("username LIKE '%[bot]'").update_all(bot: true)
  end

  def down
    remove_reference :pull_requests, :merged_by
    remove_column :contributors, :bot
  end
end
