#!/usr/bin/env ruby

# Comprehensive script to fix ALL incorrect week associations across all repositories
# Usage:
#   rails runner fix_all_week_associations.rb           # Dry run (preview only)
#   rails runner fix_all_week_associations.rb --apply   # Apply fixes

dry_run = !ARGV.include?('--apply')

puts "🔧 COMPREHENSIVE WEEK ASSOCIATION FIX"
puts "=" * 80
puts dry_run ? "🔍 DRY RUN MODE (use --apply to make changes)" : "⚡ APPLYING CHANGES"
puts "=" * 80
puts

# Statistics tracking
stats = {
  total_prs_checked: 0,
  misassociated_fixed: 0,
  missing_associations_added: 0,
  null_associations_fixed: 0,
  repositories_processed: 0,
  weeks_recalculated: 0
}

Repository.includes(:pull_requests, :weeks).find_each do |repository|
  puts "\n" + "=" * 60
  puts "PROCESSING REPOSITORY: #{repository.name}"
  puts "=" * 60

  stats[:repositories_processed] += 1
  repo_fixes = 0

  # Get all merged PRs for this repository
  merged_prs = repository.pull_requests.where.not(gh_merged_at: nil)
  puts "Found #{merged_prs.count} merged PRs"

  merged_prs.find_each.with_index do |pr, index|
    stats[:total_prs_checked] += 1

    if (index + 1) % 100 == 0
      puts "  Progress: #{index + 1}/#{merged_prs.count} PRs checked"
    end

    # Find the correct week for this PR's merge date
    correct_week = Week.find_by_date(pr.gh_merged_at)

    if correct_week.nil?
      # No week exists for this merge date - this is expected for very old/new PRs
      if pr.merged_week_id.present?
        puts "  ⚠️  PR ##{pr.number}: No week exists for merge date #{pr.gh_merged_at}, setting to NULL"
        unless dry_run
          pr.update_column(:merged_week_id, nil)
        end
        stats[:null_associations_fixed] += 1
        repo_fixes += 1
      end
      next
    end

    # Check if the PR's week association is incorrect
    if pr.merged_week_id != correct_week.id
      if pr.merged_week_id.nil?
        puts "  ➕ PR ##{pr.number}: Adding missing week association (#{correct_week.week_number})"
        stats[:missing_associations_added] += 1
      else
        current_week = Week.find_by(id: pr.merged_week_id)
        current_week_num = current_week&.week_number || 'INVALID'
        puts "  🔧 PR ##{pr.number}: Fixing misassociation #{current_week_num} → #{correct_week.week_number}"
        puts "     Merge date: #{pr.gh_merged_at}"
        puts "     Title: #{pr.title[0..60]}..."
        stats[:misassociated_fixed] += 1
      end

      unless dry_run
        pr.update_column(:merged_week_id, correct_week.id)
      end
      repo_fixes += 1
    end
  end

  puts "  ✅ #{repo_fixes} fixes needed for #{repository.name}"
end

puts "\n" + "=" * 80
puts "RECALCULATING WEEK STATISTICS"
puts "=" * 80

if dry_run
  affected_weeks = Week.joins(:merged_prs)
    .where(pull_requests: { gh_merged_at: nil })
    .or(Week.joins(:merged_prs).where.not(
      'merged_week_id = weeks.id'
    ))
    .distinct
    .count

  puts "📊 #{affected_weeks} weeks would need statistics recalculation"
  stats[:weeks_recalculated] = affected_weeks
else
  Week.includes(:repository).find_each.with_index do |week, index|
    if (index + 1) % 50 == 0
      puts "  Progress: #{index + 1}/#{Week.count} weeks recalculated"
    end

    service = WeekStatsService.new(week)
    service.update_stats
    stats[:weeks_recalculated] += 1
  end
  puts "✅ All week statistics recalculated"
end

puts "\n" + "=" * 80
puts "FINAL SUMMARY"
puts "=" * 80
puts "Repositories processed: #{stats[:repositories_processed]}"
puts "Total PRs checked: #{stats[:total_prs_checked]}"
puts "Misassociated PRs fixed: #{stats[:misassociated_fixed]}"
puts "Missing associations added: #{stats[:missing_associations_added]}"
puts "NULL associations fixed: #{stats[:null_associations_fixed]}"
puts "Weeks recalculated: #{stats[:weeks_recalculated]}"
puts

total_fixes = stats[:misassociated_fixed] + stats[:missing_associations_added] + stats[:null_associations_fixed]

if dry_run
  puts "🔍 DRY RUN COMPLETE - #{total_fixes} fixes needed"
  puts "Run with --apply to make changes"
else
  puts "✅ ALL FIXES APPLIED - #{total_fixes} issues resolved"

  # Run final verification
  puts "\n🔍 Running final verification..."
  remaining_issues = 0

  PullRequest.where.not(gh_merged_at: nil).find_each do |pr|
    correct_week = Week.find_by_date(pr.gh_merged_at)
    expected_week_id = correct_week&.id

    if pr.merged_week_id != expected_week_id
      remaining_issues += 1
    end
  end

  if remaining_issues == 0
    puts "✅ VERIFICATION PASSED - No remaining issues"
  else
    puts "❌ VERIFICATION FAILED - #{remaining_issues} issues remain"
  end
end

puts "=" * 80