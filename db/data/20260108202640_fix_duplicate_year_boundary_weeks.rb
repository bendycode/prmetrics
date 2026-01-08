# frozen_string_literal: true

class FixDuplicateYearBoundaryWeeks < ActiveRecord::Migration[7.1]
  def up
    # Find weeks with week_number ending in "00" (the buggy ones created from
    # January dates that should belong to the previous year's week 52/53)
    buggy_weeks = Week.where('week_number % 100 = 0')

    puts "Found #{buggy_weeks.count} weeks with week_number ending in 00"

    buggy_weeks.find_each do |buggy_week|
      # Calculate the correct week_number from begin_date (which is correct)
      correct_week_number = buggy_week.begin_date.strftime('%Y%W').to_i

      puts "Processing week #{buggy_week.week_number} -> should be #{correct_week_number}"

      # Find or create the correct week for this repository
      correct_week = buggy_week.repository.weeks.find_by(week_number: correct_week_number)

      if correct_week && correct_week.id != buggy_week.id
        # Merge: reassign all PR associations to the correct week
        reassign_pr_associations(buggy_week, correct_week)

        # Delete the buggy week
        puts "  Deleting duplicate week #{buggy_week.id}"
        buggy_week.destroy
      elsif correct_week.nil?
        # No correct week exists, just update the week_number
        puts "  Updating week_number from #{buggy_week.week_number} to #{correct_week_number}"
        buggy_week.update!(week_number: correct_week_number)
      else
        puts "  Week #{buggy_week.id} is already correct (same record)"
      end
    end

    puts 'Data migration complete!'
  end

  def down
    # No-op: data fix cannot be meaningfully reversed
    puts 'Data migration down: No action needed'
  end

  private

  def reassign_pr_associations(from_week, to_week)
    # Reassign ready_for_review_week associations
    count = PullRequest.where(ready_for_review_week_id: from_week.id)
                       .update_all(ready_for_review_week_id: to_week.id)
    puts "  Reassigned #{count} ready_for_review_week associations"

    # Reassign first_review_week associations
    count = PullRequest.where(first_review_week_id: from_week.id)
                       .update_all(first_review_week_id: to_week.id)
    puts "  Reassigned #{count} first_review_week associations"

    # Reassign merged_week associations
    count = PullRequest.where(merged_week_id: from_week.id)
                       .update_all(merged_week_id: to_week.id)
    puts "  Reassigned #{count} merged_week associations"

    # Reassign closed_week associations
    count = PullRequest.where(closed_week_id: from_week.id)
                       .update_all(closed_week_id: to_week.id)
    puts "  Reassigned #{count} closed_week associations"
  end
end
