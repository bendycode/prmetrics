namespace :cleanup do
  desc 'Clean up orphaned contributors with no PR associations'
  task orphaned_contributors: :environment do
    puts '🔍 Finding orphaned contributors...'

    orphaned = Contributor.left_joins(:authored_pull_requests, :reviews, :pull_request_users)
                          .where(pull_requests: { id: nil })
                          .where(reviews: { id: nil })
                          .where(pull_request_users: { id: nil })

    puts "📊 Found #{orphaned.count} orphaned contributors"

    if orphaned.any?
      puts "\n🗑️  Orphaned contributors to be deleted:"
      orphaned.each do |c|
        puts "  - #{c.username} (ID: #{c.id}, GitHub ID: #{c.github_id}, Created: #{c.created_at})"
      end

      puts "\n⚠️  This will permanently delete these contributors."
      puts "Press Ctrl+C to cancel or wait 5 seconds to continue..."

      unless ENV['SKIP_CONFIRMATION']
        sleep 5
      end

      deleted_count = 0
      orphaned.each do |c|
        c.destroy
        deleted_count += 1
        puts "  ✓ Deleted #{c.username}"
      end

      puts "\n✅ Successfully deleted #{deleted_count} orphaned contributors"
    else
      puts '✅ No orphaned contributors found'
    end
  end
end
