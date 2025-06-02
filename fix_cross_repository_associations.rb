#!/usr/bin/env ruby

puts "🔧 FIXING CROSS-REPOSITORY WEEK ASSOCIATIONS"
puts "=" * 80

# Find PRs associated with weeks from the wrong repository
mismatched_prs = PullRequest.joins(:merged_week).where('pull_requests.repository_id != weeks.repository_id')

puts "Found #{mismatched_prs.count} PRs associated with weeks from wrong repositories"
puts

if mismatched_prs.any?
  puts "DETAILS OF MISMATCHED ASSOCIATIONS:"
  puts "-" * 60
  
  mismatched_prs.includes(:repository, :merged_week).each do |pr|
    puts "\nPR ##{pr.number}: #{pr.title[0..40]}..."
    puts "  PR Repository: #{pr.repository.name} (ID: #{pr.repository_id})"
    puts "  Week Repository: #{pr.merged_week.repository.name} (ID: #{pr.merged_week.repository_id})"
    puts "  Week ID: #{pr.merged_week_id}"
    puts "  Week Number: #{pr.merged_week.week_number}"
    puts "  PR Merged at: #{pr.gh_merged_at}"
    
    # Find the correct week for this PR
    if pr.gh_merged_at
      correct_week = pr.repository.weeks.find_by_date(pr.gh_merged_at)
      
      if correct_week
        puts "  ✅ Correct week found: #{correct_week.week_number} (ID: #{correct_week.id})"
        
        if ARGV.include?('--apply')
          pr.update_column(:merged_week_id, correct_week.id)
          puts "  ✅ FIXED!"
        else
          puts "  🔍 Would fix (dry run)"
        end
      else
        puts "  ⚠️  No week found for merge date"
        
        if ARGV.include?('--apply')
          pr.update_column(:merged_week_id, nil)
          puts "  ✅ Removed association"
        else
          puts "  🔍 Would remove association (dry run)"
        end
      end
    else
      puts "  ⚠️  PR has no merge date"
      
      if ARGV.include?('--apply')
        pr.update_column(:merged_week_id, nil)
        puts "  ✅ Removed association"
      else
        puts "  🔍 Would remove association (dry run)"
      end
    end
  end
end

puts "\n" + "=" * 80
puts "CHECKING FOR INDIRECT ISSUES"
puts "=" * 80

# The real issue might be that some u-app PRs are pointing to u-node week IDs
# Let's check the specific problem weeks
problem_week_ids = [345, 346, 348]  # The 2025 u-app weeks with issues

problem_week_ids.each do |week_id|
  week = Week.find_by(id: week_id)
  next unless week
  
  puts "\nWeek ID #{week_id} (#{week.week_number}):"
  puts "  Repository: #{week.repository.name}"
  
  # Check if any of the u-node week IDs are being referenced
  u_node_week_ids = [419, 420, 428, 430, 432]
  
  # This is a bit tricky - we need to check if the merged_prs relation
  # is somehow including PRs with these IDs
  prs_with_suspicious_ids = week.repository.pull_requests
    .where(merged_week_id: week_id)
    .where(id: u_node_week_ids)
  
  if prs_with_suspicious_ids.any?
    puts "  ❌ Found PRs with IDs matching u-node week IDs!"
    prs_with_suspicious_ids.each do |pr|
      puts "    PR ID #{pr.id}: #{pr.number}"
    end
  end
  
  # Also check if somehow the count is including cross-referenced data
  direct_count = PullRequest.where(repository_id: week.repository_id, merged_week_id: week_id).count
  relation_count = week.merged_prs.count
  
  puts "  Direct SQL count: #{direct_count}"
  puts "  Relation count: #{relation_count}"
  
  if direct_count != relation_count
    puts "  ❌ COUNT MISMATCH!"
  end
end

if ARGV.include?('--apply')
  puts "\n🔄 RECALCULATING AFFECTED WEEK STATISTICS..."
  
  affected_weeks = Week.where(id: problem_week_ids)
  affected_weeks.each do |week|
    WeekStatsService.new(week).update_stats
    week.reload
    puts "Week #{week.week_number}: new count = #{week.num_prs_merged}"
  end
  
  puts "\n✅ FIXES APPLIED"
else
  puts "\n🔍 DRY RUN COMPLETE"
  puts "Run with --apply to fix the issues"
end

puts "=" * 80