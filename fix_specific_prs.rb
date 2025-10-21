#!/usr/bin/env ruby

puts "🔧 FIXING SPECIFIC MISASSOCIATED PRS"
puts "=" * 80

# The specific PRs we identified as problems
problem_prs = [419, 420, 428, 430, 432]

puts "Examining PRs: #{problem_prs.join(', ')}"
puts

problem_prs.each do |pr_number|
  pr = PullRequest.find_by(number: pr_number)

  if pr.nil?
    puts "❌ PR ##{pr_number} not found"
    next
  end

  puts "\n" + ("-" * 60)
  puts "PR ##{pr.number}: #{pr.title[0..50]}..."
  puts "  State: #{pr.state}"
  puts "  Merged at: #{pr.gh_merged_at || 'NULL'}"
  puts "  Current week association: #{pr.merged_week_id}"

  if pr.merged_week_id
    current_week = Week.find_by(id: pr.merged_week_id)
    puts "  Currently in week: #{current_week&.week_number} (#{current_week&.begin_date} to #{current_week&.end_date})" if current_week
  end

  # Find the correct week for this PR
  if pr.gh_merged_at
    correct_week = pr.repository.weeks.find_by_date(pr.gh_merged_at)

    if correct_week
      puts "  Should be in week: #{correct_week.week_number} (#{correct_week.begin_date} to #{correct_week.end_date})"

      if pr.merged_week_id != correct_week.id
        puts "  ❌ MISASSOCIATED - needs to be moved"

        if ARGV.include?('--apply')
          pr.update_column(:merged_week_id, correct_week.id)
          puts "  ✅ FIXED - moved to week #{correct_week.week_number}"
        else
          puts "  🔍 Would move to week #{correct_week.week_number} (dry run)"
        end
      else
        puts "  ✅ Already correctly associated"
      end
    else
      puts "  ⚠️  No week found for merge date #{pr.gh_merged_at}"

      if pr.merged_week_id
        if ARGV.include?('--apply')
          pr.update_column(:merged_week_id, nil)
          puts "  ✅ FIXED - removed invalid association"
        else
          puts "  🔍 Would remove association (dry run)"
        end
      end
    end
  else
    puts "  ⚠️  PR has no merge date"

    if pr.merged_week_id
      if ARGV.include?('--apply')
        pr.update_column(:merged_week_id, nil)
        puts "  ✅ FIXED - removed association from unmerged PR"
      else
        puts "  🔍 Would remove association from unmerged PR (dry run)"
      end
    end
  end
end

if ARGV.include?('--apply')
  puts "\n" + ("=" * 80)
  puts "🔄 RECALCULATING AFFECTED WEEK STATISTICS"
  puts "=" * 80

  affected_week_numbers = [202_518, 202_519, 202_521]

  affected_week_numbers.each do |week_number|
    week = Week.find_by(week_number: week_number)
    if week
      puts "Recalculating week #{week_number}..."
      WeekStatsService.new(week).update_stats
      week.reload
      puts "  New merged count: #{week.num_prs_merged}"
    end
  end

  puts "\n✅ ALL FIXES APPLIED"
else
  puts "\n" + ("=" * 80)
  puts "🔍 DRY RUN COMPLETE"
  puts "Run with --apply to make changes"
end

puts "=" * 80
