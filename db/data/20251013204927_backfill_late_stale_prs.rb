# frozen_string_literal: true

class BackfillLateStalePrs < ActiveRecord::Migration[7.1]
  def up
    puts 'Backfilling late and stale PR counts for all weeks...'
    WeekStatsService.update_all_weeks
    puts 'Backfill complete!'
  end

  def down
    # No-op: data backfill cannot be reversed
    puts 'Data migration down: No action needed'
  end
end
