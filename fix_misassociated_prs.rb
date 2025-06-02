#!/usr/bin/env ruby

puts "🔧 FIXING MISASSOCIATED PRS"
puts "=" * 80

problem_weeks = [202518, 202519, 202521]

problem_weeks.each do |week_number|
  puts "\n" + "=" * 60
  puts "FIXING WEEK #{week_number}"
  puts "=" * 60
  
  week = Week.find_by(week_number: week_number)
  next unless week
  
  puts "Repository: #{week.repository.name}"
  puts "Week range: #{week.begin_date} to #{week.end_date}"
  
  # Find PRs that are associated with this week but merged outside the time range
  week_start = week.begin_date.in_time_zone.beginning_of_day
  week_end = week.end_date.in_time_zone.end_of_day
  
  misassociated = week.merged_prs.where.not(gh_merged_at: week_start..week_end)
  
  if misassociated.any?
    puts "\n🔧 FIXING #{misassociated.count} MISASSOCIATED PRs:"
    misassociated.each do |pr|
      puts "  PR ##{pr.number}: #{pr.title[0..50]}..."
      puts "    Current week assoc: #{pr.merged_week_id}"
      puts "    Merged at: #{pr.gh_merged_at}"
      
      # Find the correct week for this PR
      if pr.gh_merged_at
        correct_week = Week.find_by_date(pr.gh_merged_at)
        if correct_week
          puts "    Correct week: #{correct_week.week_number} (ID: #{correct_week.id})"
          puts "    Updating week association..."
          pr.update_column(:merged_week_id, correct_week.id)
          puts "    ✅ Fixed!"
        else
          puts "    ❌ No week found for merge date"
          puts "    Setting to NULL..."
          pr.update_column(:merged_week_id, nil)
        end
      else
        puts "    ❌ No merge date, setting to NULL"
        pr.update_column(:merged_week_id, nil)
      end
      puts
    end
  else
    puts "✅ No misassociated PRs found"
  end
  
  # Find PRs that should be in this week but aren't associated
  should_be_associated = week.repository.pull_requests
    .where(gh_merged_at: week_start..week_end)
    .where.not(merged_week_id: week.id)
  
  if should_be_associated.any?
    puts "\n🔧 FIXING #{should_be_associated.count} MISSING ASSOCIATIONS:"
    should_be_associated.each do |pr|
      puts "  PR ##{pr.number}: #{pr.title[0..50]}..."
      puts "    Current week assoc: #{pr.merged_week_id}"
      puts "    Merged at: #{pr.gh_merged_at}"
      puts "    Should be week: #{week.week_number} (ID: #{week.id})"
      puts "    Updating week association..."
      pr.update_column(:merged_week_id, week.id)
      puts "    ✅ Fixed!"
      puts
    end
  else
    puts "✅ No missing associations found"
  end
end

puts "\n" + "=" * 80
puts "🔄 RECALCULATING WEEK STATISTICS..."

# Recalculate statistics for affected weeks
problem_weeks.each do |week_number|
  week = Week.find_by(week_number: week_number)
  next unless week
  
  puts "Recalculating week #{week_number}..."
  service = WeekStatsService.new(week)
  service.update_stats
  puts "  New merged count: #{week.reload.num_prs_merged}"
end

puts "\n✅ ALL FIXES COMPLETE!"
puts "=" * 80