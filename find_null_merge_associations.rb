#!/usr/bin/env ruby

puts "🔍 FINDING NULL MERGE DATE ASSOCIATIONS"
puts "=" * 80

# Find PRs with week associations but NULL merge dates
null_merge_with_week = PullRequest.where(gh_merged_at: nil).where.not(merged_week_id: nil)

puts "Found #{null_merge_with_week.count} PRs with NULL merge dates but week associations"
puts

if null_merge_with_week.any?
  puts "These PRs should NOT have week associations:"
  null_merge_with_week.includes(:merged_week).each do |pr|
    puts "  PR ##{pr.number}: #{pr.title[0..50]}..."
    puts "    State: #{pr.state}"
    puts "    Merged at: #{pr.gh_merged_at || 'NULL'}"
    puts "    Associated with week: #{pr.merged_week&.week_number} (ID: #{pr.merged_week_id})"
    puts
  end
end

puts "=" * 80
puts "CHECKING PROBLEM WEEKS FOR NULL MERGE ASSOCIATIONS"
puts "=" * 80

problem_weeks = [202518, 202519, 202521]

problem_weeks.each do |week_number|
  week = Week.find_by(week_number: week_number)
  next unless week

  puts "\nWeek #{week_number}:"

  # Count all associations
  total_associated = week.merged_prs.count

  # Count associations with actual merge dates
  with_merge_dates = week.merged_prs.where.not(gh_merged_at: nil).count

  # Count associations with NULL merge dates
  null_merge_dates = week.merged_prs.where(gh_merged_at: nil).count

  puts "  Total associations: #{total_associated}"
  puts "  With merge dates: #{with_merge_dates}"
  puts "  With NULL merge dates: #{null_merge_dates}"

  if null_merge_dates > 0
    puts "  ❌ Found #{null_merge_dates} PRs with NULL merge dates!"
    week.merged_prs.where(gh_merged_at: nil).each do |pr|
      puts "    - PR ##{pr.number}: #{pr.title[0..40]}... (state: #{pr.state})"
    end
  end

  # Now check if all PRs with merge dates are in the correct range
  week_start = week.begin_date.in_time_zone.beginning_of_day
  week_end = week.end_date.in_time_zone.end_of_day

  outside_range = week.merged_prs
    .where.not(gh_merged_at: nil)
    .where.not(gh_merged_at: week_start..week_end)

  if outside_range.any?
    puts "  ❌ Found #{outside_range.count} PRs merged outside week range!"
    outside_range.each do |pr|
      puts "    - PR ##{pr.number}: merged at #{pr.gh_merged_at}"
    end
  end
end

puts "\n" + "=" * 80
puts "CORRECT FIX APPROACH"
puts "=" * 80

puts "To fix these issues:"
puts "1. Remove week associations from PRs with NULL merge dates"
puts "2. Reassign PRs that are merged outside their associated week's range"
puts "3. Recalculate week statistics"

total_to_fix = null_merge_with_week.count
puts "\nTotal PRs to fix: #{total_to_fix}"