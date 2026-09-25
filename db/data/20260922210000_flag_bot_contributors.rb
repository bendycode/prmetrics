# frozen_string_literal: true

# Every GitHub App's login ends in [bot], which no human login can contain, so
# the suffix seeds the flag for contributors stored before the sync recorded
# the account type. The sync adds the accounts the suffix misses, such as
# Copilot, as it sees each contributor again. Plain SQL keeps this migration
# independent of the model classes.
class FlagBotContributors < ActiveRecord::Migration[7.2]
  def up
    execute "UPDATE contributors SET bot = true WHERE username LIKE '%[bot]'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
