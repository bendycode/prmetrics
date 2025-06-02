namespace :fix do
  desc "Recalculate all week statistics using week associations"
  task week_stats: :environment do
    puts "🔄 Recalculating all week statistics..."
    
    total_weeks = Week.count
    updated = 0
    
    Week.includes(:repository).find_each.with_index do |week, index|
      service = WeekStatsService.new(week)
      service.update_stats
      updated += 1
      
      if (index + 1) % 10 == 0
        puts "  Progress: #{index + 1}/#{total_weeks} weeks updated"
      end
    end
    
    puts "✅ Successfully recalculated statistics for #{updated} weeks"
  end
  
  desc "Check for week statistics discrepancies"
  task check_week_discrepancies: :environment do
    puts "🔍 Checking for week statistics discrepancies..."
    
    discrepancies_found = 0
    
    Week.includes(:repository).find_each do |week|
      # Check merged PRs
      actual_merged = week.repository.pull_requests.where(merged_week_id: week.id).count
      if week.num_prs_merged != actual_merged
        puts "\n⚠️  Week #{week.week_number} (#{week.repository.name}):"
        puts "  Stored merged count: #{week.num_prs_merged}"
        puts "  Actual merged count: #{actual_merged}"
        discrepancies_found += 1
      end
      
      # Check started PRs
      actual_started = week.repository.pull_requests
        .where(draft: false)
        .where(ready_for_review_week_id: week.id)
        .count
      if week.num_prs_started != actual_started
        puts "\n⚠️  Week #{week.week_number} (#{week.repository.name}):"
        puts "  Stored started count: #{week.num_prs_started}"
        puts "  Actual started count: #{actual_started}"
        discrepancies_found += 1
      end
    end
    
    if discrepancies_found == 0
      puts "✅ No discrepancies found!"
    else
      puts "\n❌ Found #{discrepancies_found} discrepancies. Run 'rake fix:week_stats' to fix them."
    end
  end
end