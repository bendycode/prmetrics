namespace :fix do
  desc "Update week associations for all pull requests"
  task update_week_associations: :environment do
    puts "🔄 Updating week associations for all pull requests..."
    
    total_prs = PullRequest.count
    updated = 0
    
    PullRequest.includes(:repository).find_each.with_index do |pr, index|
      pr.ensure_weeks_exist_and_update_associations
      updated += 1
      
      if (index + 1) % 100 == 0
        puts "  Progress: #{index + 1}/#{total_prs} PRs updated"
      end
    end
    
    puts "✅ Successfully updated week associations for #{updated} pull requests"
  end
end