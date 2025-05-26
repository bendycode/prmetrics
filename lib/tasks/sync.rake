namespace :sync do
  desc "Clean up stuck 'in_progress' syncs"
  task cleanup_stuck_syncs: :environment do
    # Find repositories that have been "in_progress" for more than 2 hours
    stuck_repos = Repository.where(sync_status: 'in_progress')
                           .where('sync_started_at < ?', 2.hours.ago)
    
    stuck_repos.each do |repo|
      Rails.logger.info "Marking #{repo.name} sync as failed (stuck for > 2 hours)"
      repo.update!(
        sync_status: 'failed',
        last_sync_error: 'Sync timed out or was cancelled'
      )
    end
    
    puts "Updated #{stuck_repos.count} stuck repositories"
  end
  
  desc "Reset sync status for a specific repository"
  task :reset_status, [:repo_name] => :environment do |t, args|
    repo = Repository.find_by(name: args[:repo_name])
    if repo
      repo.update!(
        sync_status: 'failed',
        last_sync_error: 'Sync was manually cancelled'
      )
      puts "Reset sync status for #{repo.name}"
    else
      puts "Repository not found: #{args[:repo_name]}"
    end
  end
end