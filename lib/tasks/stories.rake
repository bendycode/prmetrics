namespace :sync do
  desc "Sync every tracker's stories and measure their cycle times (for nightly cron jobs)"
  task stories: :environment do
    unless ENV['GITHUB_ACCESS_TOKEN']
      puts 'Error: GITHUB_ACCESS_TOKEN environment variable is not set'
      exit 1
    end

    trackers = Tracker.includes(:source_repository).order(:id).to_a
    synced = trackers.count do |tracker|
      StorySyncService.new(tracker).sync!
      puts "  ✓ Synced stories for #{tracker.source_repository.name}"
      true
    rescue StandardError => e
      puts "  ✗ Failed to sync stories for #{tracker.source_repository.name}: #{e.message}"
      Rails.logger.error "Story sync failed for tracker #{tracker.id}: #{e.message}"
      false
    end

    puts "Synced #{synced} of #{trackers.size} trackers"
    exit 1 if synced < trackers.size
  end
end
