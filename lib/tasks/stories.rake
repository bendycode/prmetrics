namespace :sync do
  desc "Sync every tracker's stories and measure their cycle times (for nightly cron jobs)"
  task stories: :environment do
    # This output and the app's log both reach the nightly workflow's log,
    # which is public, so they name trackers by ID and errors by class: a
    # tracker's repository may be private, and a GitHub error's message
    # quotes its URL. Each kind of sync checks for its own credentials, so a
    # tracker missing them fails alone.
    trackers = Tracker.includes(:source_repository).order(:id).to_a
    synced = trackers.count do |tracker|
      tracker.sync!
      puts "  ✓ Synced stories for tracker #{tracker.id}"
      true
    rescue StandardError => e
      puts "  ✗ Failed to sync stories for tracker #{tracker.id}: #{e.class}"
      Rails.logger.error "Story sync failed for tracker #{tracker.id}: #{e.class}"
      false
    end

    puts "Synced #{synced} of #{trackers.size} trackers"
    exit 1 if synced < trackers.size
  end
end
