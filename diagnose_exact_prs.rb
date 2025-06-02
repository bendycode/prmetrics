#!/usr/bin/env ruby

puts "🔍 EXACT PR DIAGNOSIS FOR PROBLEM WEEKS"
puts "=" * 80

problem_weeks = [202518, 202519, 202521]

problem_weeks.each do |week_number|
  week = Week.find_by(week_number: week_number)
  next unless week
  
  puts "\n" + "=" * 60
  puts "WEEK #{week_number}"
  puts "=" * 60
  
  week_start = week.begin_date.in_time_zone.beginning_of_day
  week_end = week.end_date.in_time_zone.end_of_day
  
  puts "Week range: #{week_start} to #{week_end}"
  puts "Week ID: #{week.id}"
  
  # Get all PRs associated with this week
  associated_prs = week.merged_prs.order(:number)
  
  # Get all PRs that should be in this week based on merge timestamp
  timestamp_prs = week.repository.pull_requests
    .where(gh_merged_at: week_start..week_end)
    .order(:number)
  
  puts "\nASSOCIATED PRs (via merged_week_id = #{week.id}): #{associated_prs.count}"
  associated_pr_numbers = associated_prs.pluck(:number, :gh_merged_at).map do |num, merged_at|
    in_range = merged_at && merged_at >= week_start && merged_at <= week_end
    { number: num, merged_at: merged_at, in_range: in_range }
  end
  
  puts "\nTIMESTAMP PRs (merged in week range): #{timestamp_prs.count}"
  timestamp_pr_numbers = timestamp_prs.pluck(:number, :merged_week_id)
  
  # Find PRs that are associated but not in timestamp range
  associated_only = associated_pr_numbers.select { |pr| !pr[:in_range] }
  
  if associated_only.any?
    puts "\n❌ PRs ASSOCIATED BUT NOT IN WEEK RANGE:"
    associated_only.each do |pr|
      puts "  PR ##{pr[:number]}: merged at #{pr[:merged_at]}"
      
      # Find which week this PR should belong to
      pr_record = PullRequest.find_by(number: pr[:number])
      if pr_record
        correct_week = pr_record.repository.weeks
          .where('begin_date <= ? AND end_date >= ?', 
                 pr_record.gh_merged_at.to_date, 
                 pr_record.gh_merged_at.to_date)
          .first
        
        if correct_week
          puts "    Should be in week #{correct_week.week_number}"
        else
          puts "    No week found for this merge date!"
        end
      end
    end
  end
  
  # Find PRs that should be associated but aren't
  timestamp_not_associated = timestamp_pr_numbers.select { |num, week_id| week_id != week.id }
  
  if timestamp_not_associated.any?
    puts "\n❌ PRs IN WEEK RANGE BUT NOT ASSOCIATED:"
    timestamp_not_associated.each do |num, week_id|
      pr = PullRequest.find_by(number: num)
      puts "  PR ##{num}: currently associated with week_id #{week_id}"
      if pr
        puts "    Merged at: #{pr.gh_merged_at}"
      end
    end
  end
  
  # Direct SQL query to double-check
  puts "\n📊 DIRECT SQL VERIFICATION:"
  
  sql_associated = ActiveRecord::Base.connection.execute(
    "SELECT COUNT(*) as count FROM pull_requests WHERE merged_week_id = #{week.id}"
  ).first['count']
  
  sql_in_range = ActiveRecord::Base.connection.execute(
    "SELECT COUNT(*) as count FROM pull_requests 
     WHERE repository_id = #{week.repository_id}
     AND gh_merged_at >= '#{week_start.utc.iso8601}'
     AND gh_merged_at <= '#{week_end.utc.iso8601}'"
  ).first['count']
  
  puts "  SQL: #{sql_associated} PRs have merged_week_id = #{week.id}"
  puts "  SQL: #{sql_in_range} PRs merged in timestamp range"
  
  if sql_associated != sql_in_range
    puts "\n🔍 INVESTIGATING DIFFERENCE:"
    
    # Get the actual PR numbers
    associated_sql = ActiveRecord::Base.connection.execute(
      "SELECT number, gh_merged_at FROM pull_requests WHERE merged_week_id = #{week.id} ORDER BY number"
    )
    
    in_range_sql = ActiveRecord::Base.connection.execute(
      "SELECT number, merged_week_id FROM pull_requests 
       WHERE repository_id = #{week.repository_id}
       AND gh_merged_at >= '#{week_start.utc.iso8601}'
       AND gh_merged_at <= '#{week_end.utc.iso8601}'
       ORDER BY number"
    )
    
    associated_nums = associated_sql.map { |r| r['number'] }
    in_range_nums = in_range_sql.map { |r| r['number'] }
    
    extra_associated = associated_nums - in_range_nums
    missing_associated = in_range_nums - associated_nums
    
    if extra_associated.any?
      puts "  Extra PRs associated: #{extra_associated.join(', ')}"
    end
    
    if missing_associated.any?
      puts "  PRs that should be associated: #{missing_associated.join(', ')}"
    end
  end
end

puts "\n" + "=" * 80