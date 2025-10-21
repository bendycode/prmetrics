#!/usr/bin/env ruby

# Properly fix week associations including NULL merge dates
# Usage:
#   rails runner fix_week_associations_properly.rb           # Dry run
#   rails runner fix_week_associations_properly.rb --apply   # Apply fixes

dry_run = !ARGV.include?('--apply')

puts '🔧 PROPER WEEK ASSOCIATION FIX'
puts '=' * 80
puts dry_run ? '🔍 DRY RUN MODE (use --apply to make changes)' : '⚡ APPLYING CHANGES'
puts '=' * 80
puts

stats = {
  null_merge_fixed: 0,
  misassociated_fixed: 0,
  missing_associations_added: 0,
  total_fixes: 0
}

# First, fix PRs with NULL merge dates that have week associations
puts 'STEP 1: Fixing PRs with NULL merge dates'
puts '-' * 40

null_merge_with_week = PullRequest.where(gh_merged_at: nil).where.not(merged_week_id: nil)
puts "Found #{null_merge_with_week.count} PRs with NULL merge dates but week associations"

null_merge_with_week.each do |pr|
  puts "  PR ##{pr.number}: Removing invalid week association"
  unless dry_run
    pr.update_column(:merged_week_id, nil)
  end
  stats[:null_merge_fixed] += 1
end

puts "\nSTEP 2: Fixing misassociated PRs"
puts '-' * 40

# For each week, check all associated PRs
Week.includes(:repository).find_each do |week|
  week_start = week.begin_date.in_time_zone.beginning_of_day
  week_end = week.end_date.in_time_zone.end_of_day

  # Find PRs associated with this week but merged outside its range
  misassociated = week.merged_prs
                      .where.not(gh_merged_at: nil)
                      .where.not(gh_merged_at: week_start..week_end)

  if misassociated.any?
    puts "\nWeek #{week.week_number} has #{misassociated.count} misassociated PRs:"

    misassociated.each do |pr|
      correct_week = Week.find_by_date(pr.gh_merged_at)

      if correct_week
        puts "  PR ##{pr.number}: Moving from week #{week.week_number} to #{correct_week.week_number}"
        unless dry_run
          pr.update_column(:merged_week_id, correct_week.id)
        end
      else
        puts "  PR ##{pr.number}: No week exists for merge date, removing association"
        unless dry_run
          pr.update_column(:merged_week_id, nil)
        end
      end
      stats[:misassociated_fixed] += 1
    end
  end
end

puts "\nSTEP 3: Adding missing associations"
puts '-' * 40

# Find all PRs with merge dates but no week association
PullRequest.where.not(gh_merged_at: nil).where(merged_week_id: nil).find_each do |pr|
  week = Week.find_by_date(pr.gh_merged_at)

  if week
    puts "  PR ##{pr.number}: Adding association to week #{week.week_number}"
    unless dry_run
      pr.update_column(:merged_week_id, week.id)
    end
    stats[:missing_associations_added] += 1
  end
end

stats[:total_fixes] = stats[:null_merge_fixed] + stats[:misassociated_fixed] + stats[:missing_associations_added]

puts "\n" + ('=' * 80)
puts 'SUMMARY'
puts '=' * 80
puts "NULL merge associations removed: #{stats[:null_merge_fixed]}"
puts "Misassociated PRs fixed: #{stats[:misassociated_fixed]}"
puts "Missing associations added: #{stats[:missing_associations_added]}"
puts "Total fixes: #{stats[:total_fixes]}"

if dry_run
  puts "\n🔍 DRY RUN COMPLETE"
  puts 'Run with --apply to make changes'
else
  puts "\n✅ FIXES APPLIED"

  # Recalculate week statistics
  puts "\n🔄 Recalculating week statistics..."
  Week.find_each do |week|
    WeekStatsService.new(week).update_stats
  end
  puts '✅ Week statistics updated'

  # Verification
  puts "\n🔍 Running verification..."
  remaining_issues = PullRequest.where(gh_merged_at: nil).where.not(merged_week_id: nil).count

  if remaining_issues == 0
    puts '✅ No PRs with NULL merge dates have week associations'
  else
    puts "❌ Still found #{remaining_issues} PRs with NULL merge dates and week associations"
  end
end

puts '=' * 80
