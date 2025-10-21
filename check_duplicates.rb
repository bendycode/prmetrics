#!/usr/bin/env ruby

# Quick script to check for duplicate week records
repo_name = ARGV[0] || 'pureoxygen/u-app'

puts "Checking for duplicate week records in #{repo_name}..."

repo = Repository.find_by(name: repo_name)
unless repo
  puts "Repository '#{repo_name}' not found!"
  exit 1
end

duplicates = repo.weeks.group(:week_number).having('COUNT(*) > 1').count
total_weeks = repo.weeks.count

puts "Repository: #{repo.name}"
puts "Total weeks: #{total_weeks}"

if duplicates.empty?
  puts "✅ No duplicate week records found"
else
  puts "❌ Found duplicate week_numbers:"
  duplicates.each do |week_number, count|
    puts "  Week #{week_number}: #{count} records"
  end

  puts "\nDetailed duplicate records:"
  duplicates.keys.each do |week_number|
    weeks = repo.weeks.where(week_number: week_number).order(:created_at)
    puts "  Week #{week_number}:"
    weeks.each_with_index do |week, i|
      puts "    #{i+1}. ID: #{week.id}, Created: #{week.created_at}, Begin: #{week.begin_date}"
    end
  end
end
