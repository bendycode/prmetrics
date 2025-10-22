#!/usr/bin/env ruby

puts '🔍 DIAGNOSING DUPLICATE WEEK NUMBERS'
puts '=' * 80

# Check for duplicate week numbers
duplicate_week_numbers = Week.group(:week_number)
                             .having('COUNT(*) > 1')
                             .pluck(:week_number)

puts "Found #{duplicate_week_numbers.count} duplicate week numbers"
puts

if duplicate_week_numbers.any?
  duplicate_week_numbers.sort.each do |week_num|
    puts "\nWeek number #{week_num}:"

    weeks = Week.where(week_number: week_num).includes(:repository).order(:begin_date)
    weeks.each do |week|
      puts "  ID: #{week.id}, Repo: #{week.repository.name}"
      puts "  Date range: #{week.begin_date} to #{week.end_date}"
      puts "  Merged PRs: #{week.merged_prs.count}"
    end
  end
end

puts "\n" + ('=' * 80)
puts 'CHECKING SPECIFIC PROBLEM WEEKS'
puts '=' * 80

[202_518, 202_519, 202_521].each do |week_num|
  puts "\nWeek #{week_num}:"

  weeks = Week.where(week_number: week_num)
  puts "  Found #{weeks.count} week(s) with this number"

  weeks.each do |week|
    puts "  Week ID #{week.id}: #{week.begin_date} to #{week.end_date}"

    # Check if any of the "extra" PRs are associated with this week
    [419, 420, 428, 430, 432].each do |pr_num|
      puts "    ❌ Contains PR ##{pr_num}" if week.merged_prs.exists?(number: pr_num)
    end
  end
end

puts "\n" + ('=' * 80)
puts 'CHECKING YEAR OVERLAP ISSUE'
puts '=' * 80

# Week 202518 could be interpreted as:
# - 2025 week 18
# - 2020 week 2518 (which doesn't make sense)

# Let's check what years have week 18
week_18s = Week.where('week_number % 100 = 18').order(:begin_date)
puts "\nAll weeks ending in 18:"
week_18s.each do |week|
  puts "  Week #{week.week_number}: #{week.begin_date.year} (#{week.begin_date} to #{week.end_date})"
  puts "    ID: #{week.id}, Merged PRs: #{week.merged_prs.count}"
end

puts "\n" + ('=' * 80)
puts 'CHECKING PR ASSOCIATIONS FOR WRONG YEAR'
puts '=' * 80

# Check if 2025 weeks have 2020 PRs associated
Week.where('begin_date >= ?', Date.new(2025, 1, 1)).each do |week|
  old_prs = week.merged_prs.where('gh_merged_at < ?', Date.new(2021, 1, 1))

  next unless old_prs.any?

  puts "\n❌ Week #{week.week_number} (#{week.begin_date}) has old PRs:"
  old_prs.each do |pr|
    puts "  PR ##{pr.number}: merged #{pr.gh_merged_at}"
  end
end
