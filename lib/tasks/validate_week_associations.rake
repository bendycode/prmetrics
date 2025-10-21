namespace :validate do
  desc "Check for week association inconsistencies and optionally fix them"
  task week_associations: :environment do
    puts "🔍 Validating week associations for all pull requests..."

    inconsistent_prs = []
    orphaned_weeks = []
    total_prs = PullRequest.count
    checked = 0

    PullRequest.includes(:repository, :merged_week, :ready_for_review_week, :first_review_week, :closed_week).find_each do |pr|
      checked += 1

      if (checked % 500) == 0
        puts "  Progress: #{checked}/#{total_prs} PRs checked"
      end

      # Check merged week association
      if pr.gh_merged_at
        expected_merged_week = Week.find_by_date(pr.gh_merged_at)
        if pr.merged_week != expected_merged_week
          inconsistent_prs << {
            pr: pr,
            field: :merged_week,
            current: pr.merged_week&.week_number,
            expected: expected_merged_week&.week_number
          }
        end
      end

      # Check ready for review week association
      if pr.ready_for_review_at
        expected_ready_week = Week.find_by_date(pr.ready_for_review_at)
        if pr.ready_for_review_week != expected_ready_week
          inconsistent_prs << {
            pr: pr,
            field: :ready_for_review_week,
            current: pr.ready_for_review_week&.week_number,
            expected: expected_ready_week&.week_number
          }
        end
      end

      # Check closed week association
      if pr.gh_closed_at
        expected_closed_week = Week.find_by_date(pr.gh_closed_at)
        if pr.closed_week != expected_closed_week
          inconsistent_prs << {
            pr: pr,
            field: :closed_week,
            current: pr.closed_week&.week_number,
            expected: expected_closed_week&.week_number
          }
        end
      end
    end

    # Check for orphaned week records (weeks with no associated PRs)
    Week.find_each do |week|
      pr_count = week.repository.pull_requests.where(
        "merged_week_id = ? OR ready_for_review_week_id = ? OR first_review_week_id = ? OR closed_week_id = ?",
        week.id, week.id, week.id, week.id
      ).count

      if pr_count == 0
        orphaned_weeks << week
      end
    end

    puts "\n📊 Validation Results:"
    puts "  Total PRs checked: #{checked}"
    puts "  Inconsistent PR associations: #{inconsistent_prs.size}"
    puts "  Orphaned weeks: #{orphaned_weeks.size}"

    if inconsistent_prs.any?
      puts "\n⚠️  Inconsistent PR associations found:"
      inconsistent_prs.first(10).each do |issue|
        pr = issue[:pr]
        puts "  PR ##{pr.number} (#{pr.repository.name}): #{issue[:field]}"
        puts "    Current: week #{issue[:current] || 'NULL'}"
        puts "    Expected: week #{issue[:expected] || 'NULL'}"
      end

      if inconsistent_prs.size > 10
        puts "  ... and #{inconsistent_prs.size - 10} more"
      end

      puts "\n🔧 To fix these issues, run: rake fix:week_associations"
    end

    if orphaned_weeks.any?
      puts "\n🗑️  Orphaned weeks found:"
      orphaned_weeks.first(10).each do |week|
        puts "  Week #{week.week_number} (#{week.repository.name}): #{week.begin_date} - #{week.end_date}"
      end

      if orphaned_weeks.size > 10
        puts "  ... and #{orphaned_weeks.size - 10} more"
      end
    end

    if inconsistent_prs.empty? && orphaned_weeks.empty?
      puts "✅ All week associations are consistent!"
    end
  end
end

namespace :fix do
  desc "Fix inconsistent week associations"
  task week_associations: :environment do
    puts "🔧 Fixing inconsistent week associations..."

    fixed_count = 0
    total_prs = PullRequest.count

    PullRequest.find_each.with_index do |pr, index|
      if (index + 1) % 500 == 0
        puts "  Progress: #{index + 1}/#{total_prs} PRs processed"
      end

      old_merged_week = pr.merged_week_id
      old_ready_week = pr.ready_for_review_week_id
      old_first_review_week = pr.first_review_week_id
      old_closed_week = pr.closed_week_id

      # Update associations without triggering callbacks to avoid recursion
      pr.update_week_associations

      if pr.merged_week_id != old_merged_week ||
         pr.ready_for_review_week_id != old_ready_week ||
         pr.first_review_week_id != old_first_review_week ||
         pr.closed_week_id != old_closed_week
        fixed_count += 1
      end
    end

    puts "✅ Fixed week associations for #{fixed_count} pull requests"
  end
end