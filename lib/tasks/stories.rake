namespace :sync do
  desc "Sync every tracker's stories and measure their cycle times (for nightly cron jobs)"
  task stories: :environment do
    unless ENV['GITHUB_ACCESS_TOKEN']
      puts 'Error: GITHUB_ACCESS_TOKEN environment variable is not set'
      exit 1
    end

    # This output reaches the nightly workflow's log, which is public, so it
    # names trackers by ID: a tracker's repository, and an error message
    # quoting its URL, may be private. The app's own log gets the message.
    trackers = Tracker.includes(:source_repository).order(:id).to_a
    synced = trackers.count do |tracker|
      StorySyncService.new(tracker).sync!
      puts "  ✓ Synced stories for tracker #{tracker.id}"
      true
    rescue StandardError => e
      puts "  ✗ Failed to sync stories for tracker #{tracker.id}: #{e.class}"
      Rails.logger.error "Story sync failed for tracker #{tracker.id}: #{e.message}"
      false
    end

    puts "Synced #{synced} of #{trackers.size} trackers"
    exit 1 if synced < trackers.size
  end
end
