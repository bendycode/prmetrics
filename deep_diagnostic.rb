#!/usr/bin/env ruby

puts "🔍 DEEP DIAGNOSTIC: Finding Exact Differences"
puts "=" * 80

# Development data we know
dev_data = {
  202518 => 6,
  202519 => 18,
  202521 => 11
}

puts "Development counts: #{dev_data}"
puts

problem_weeks = [202518, 202519, 202521]

problem_weeks.each do |week_number|
  puts "\n" + ("=" * 60)
  puts "WEEK #{week_number} DETAILED ANALYSIS"
  puts "=" * 60

  week = Week.find_by(week_number: week_number)
  unless week
    puts "❌ Week #{week_number} not found!"
    next
  end

  puts "Repository: #{week.repository.name}"
  puts "Week ID: #{week.id}"
  puts "Week range: #{week.begin_date} to #{week.end_date}"
  puts "Time zone: #{Time.zone}"
  puts

  # Multiple counting methods
  stored_count = week.num_prs_merged
  association_count = week.merged_prs.count

  # Timestamp method with exact boundaries
  week_start = week.begin_date.in_time_zone.beginning_of_day
  week_end = week.end_date.in_time_zone.end_of_day
  timestamp_count = week.repository.pull_requests
                        .where(gh_merged_at: week_start..week_end)
                        .count

  # UTC boundaries for comparison
  utc_start = week.begin_date.beginning_of_day.utc
  utc_end = week.end_date.end_of_day.utc
  utc_count = week.repository.pull_requests
                  .where(gh_merged_at: utc_start..utc_end)
                  .count

  puts "COUNTS:"
  puts "  Stored (num_prs_merged): #{stored_count}"
  puts "  Via association: #{association_count}"
  puts "  Via timestamp (TZ): #{timestamp_count}"
  puts "  Via timestamp (UTC): #{utc_count}"
  puts "  Development expected: #{dev_data[week_number]}"
  puts

  # Find discrepancies
  if stored_count != dev_data[week_number]
    puts "❌ STORED COUNT DISCREPANCY!"
    puts "   Production: #{stored_count}, Development: #{dev_data[week_number]}"
  end

  if association_count != dev_data[week_number]
    puts "❌ ASSOCIATION COUNT DISCREPANCY!"
    puts "   Production: #{association_count}, Development: #{dev_data[week_number]}"
  end

  if timestamp_count != dev_data[week_number]
    puts "❌ TIMESTAMP COUNT DISCREPANCY!"
    puts "   Production: #{timestamp_count}, Development: #{dev_data[week_number]}"
  end

  puts

  # List ALL PRs merged in the timestamp range
  prs_in_range = week.repository.pull_requests
                     .where(gh_merged_at: week_start..week_end)
                     .order(:gh_merged_at)

  puts "PRs MERGED IN TIME RANGE (#{week_start} to #{week_end}):"
  prs_in_range.each_with_index do |pr, i|
    week_assoc = pr.merged_week_id == week.id ? "✅" : "❌"
    puts "  #{i+1}. PR ##{pr.number}: #{pr.title[0..50]}..."
    puts "     Merged: #{pr.gh_merged_at}"
    puts "     Week assoc: #{week_assoc} (ID: #{pr.merged_week_id})"
    puts
  end

  # List PRs associated with this week but merged outside range
  misassociated = week.merged_prs.where.not(gh_merged_at: week_start..week_end)
  if misassociated.any?
    puts "\n⚠️  PRs ASSOCIATED WITH THIS WEEK BUT MERGED OUTSIDE RANGE:"
    misassociated.each do |pr|
      puts "  PR ##{pr.number}: #{pr.title[0..50]}..."
      puts "     Merged: #{pr.gh_merged_at}"
      puts "     Week assoc ID: #{pr.merged_week_id}"
      puts
    end
  end

  puts "\nWEEK BOUNDARY DEBUG:"
  puts "  begin_date: #{week.begin_date} (#{week.begin_date.class})"
  puts "  end_date: #{week.end_date} (#{week.end_date.class})"
  puts "  week_start: #{week_start} (#{week_start.class})"
  puts "  week_end: #{week_end} (#{week_end.class})"
  puts "  Time.zone: #{Time.zone}"
  puts "  Time.zone.now: #{Time.zone.now}"
end

puts "\n" + ("=" * 80)
puts "ENVIRONMENT INFO:"
puts "  Rails.env: #{Rails.env}"
puts "  Time.zone: #{Time.zone}"
puts "  Database timezone: #{ActiveRecord::Base.connection.execute('SHOW timezone').first['TimeZone'] rescue 'unknown'}"
puts "  Current time: #{Time.current}"
puts "=" * 80
