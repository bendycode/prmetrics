#!/usr/bin/env ruby

puts '🔍 INVESTIGATING WEEK ASSOCIATION LOGIC'
puts '=' * 80

# Focus on the problem weeks we know have issues
problem_weeks = [202_518, 202_519, 202_521]

problem_weeks.each do |week_number|
  week = Week.find_by(week_number: week_number)
  next unless week

  puts "\n" + ('=' * 60)
  puts "WEEK #{week_number} DEEP INVESTIGATION"
  puts '=' * 60

  puts "Week ID: #{week.id}"
  puts "Repository: #{week.repository.name}"
  puts "Date range: #{week.begin_date} to #{week.end_date}"

  # Get time boundaries
  week_start = week.begin_date.in_time_zone.beginning_of_day
  week_end = week.end_date.in_time_zone.end_of_day

  puts "\nTime boundaries:"
  puts "  week_start: #{week_start}"
  puts "  week_end: #{week_end}"

  # Count PRs via association
  associated_prs = week.merged_prs
  puts "\nPRs via association (merged_week_id = #{week.id}): #{associated_prs.count}"

  # Count PRs via timestamp
  timestamp_prs = week.repository.pull_requests.where(gh_merged_at: week_start..week_end)
  puts "PRs via timestamp range: #{timestamp_prs.count}"

  # Find PRs that are associated but shouldn't be
  puts "\n🔍 CHECKING FOR MISASSOCIATED PRS:"
  misassociated = associated_prs.where.not(gh_merged_at: week_start..week_end)

  if misassociated.any?
    puts "Found #{misassociated.count} PRs associated with this week but merged outside range:"
    misassociated.each do |pr|
      puts "  PR ##{pr.number}:"
      puts "    Merged at: #{pr.gh_merged_at}"
      puts "    Merged week ID: #{pr.merged_week_id}"

      # What week SHOULD this PR belong to?
      correct_week = Week.find_by_date(pr.gh_merged_at)
      if correct_week
        puts "    Should be week: #{correct_week.week_number} (ID: #{correct_week.id})"
      else
        puts '    Should be week: NONE (no week for this date)'
      end

      # Test Week.find_by_date logic
      puts "    Testing Week.find_by_date(#{pr.gh_merged_at}):"
      test_date = pr.gh_merged_at.respond_to?(:to_date) ? pr.gh_merged_at.to_date : pr.gh_merged_at
      matching_weeks = Week.where('begin_date <= ? AND end_date >= ?', test_date, test_date)
      puts "    Found #{matching_weeks.count} matching weeks"
      matching_weeks.each do |w|
        puts "      Week #{w.week_number}: #{w.begin_date} to #{w.end_date}"
      end
    end
  else
    puts '✅ No misassociated PRs found'
  end

  # Find PRs that should be associated but aren't
  puts "\n🔍 CHECKING FOR MISSING ASSOCIATIONS:"
  missing = timestamp_prs.where.not(merged_week_id: week.id)

  if missing.any?
    puts "Found #{missing.count} PRs that should be in this week but aren't:"
    missing.each do |pr|
      puts "  PR ##{pr.number}:"
      puts "    Merged at: #{pr.gh_merged_at}"
      puts "    Current week ID: #{pr.merged_week_id}"
    end
  else
    puts '✅ No missing associations found'
  end
end

puts "\n" + ('=' * 80)
puts 'TESTING Week.find_by_date LOGIC'
puts '=' * 80

# Test some specific dates
test_dates = [
  Time.zone.parse('2025-05-05 12:13:43'),  # Should be week 202518
  Time.zone.parse('2025-05-12 11:00:30'),  # Should be week 202519
  Time.zone.parse('2025-05-26 11:04:12')   # Should be week 202521
]

test_dates.each do |date|
  puts "\nTesting date: #{date}"
  week = Week.find_by_date(date)
  if week
    puts "  Found week: #{week.week_number} (#{week.begin_date} to #{week.end_date})"
  else
    puts '  No week found!'
  end

  # Also test with date object
  date_obj = date.to_date
  week2 = Week.find_by_date(date_obj)
  if week2
    puts "  Found week (using date): #{week2.week_number}"
  else
    puts '  No week found (using date)!'
  end
end

puts "\n" + ('=' * 80)
puts 'DATABASE WEEK OVERLAP CHECK'
puts '=' * 80

# Check for overlapping weeks
overlaps = []
Week.find_each do |week1|
  Week.where('id > ?', week1.id).where(repository_id: week1.repository_id).each do |week2|
    if week1.begin_date <= week2.end_date && week2.begin_date <= week1.end_date
      overlaps << [week1, week2]
    end
  end
end

if overlaps.any?
  puts "❌ Found #{overlaps.count} overlapping week pairs!"
  overlaps.each do |w1, w2|
    puts "  Week #{w1.week_number} (#{w1.begin_date} to #{w1.end_date})"
    puts '  overlaps with'
    puts "  Week #{w2.week_number} (#{w2.begin_date} to #{w2.end_date})"
    puts
  end
else
  puts '✅ No overlapping weeks found'
end

puts '=' * 80
