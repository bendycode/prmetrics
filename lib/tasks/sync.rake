namespace :sync do
  desc "Unified sync: fetch PRs, generate weeks, and update stats with real-time progress"
  task :repository, [:repo_name] => :environment do |t, args|
    # Handle both bracketed and non-bracketed syntax
    # Only use ARGV if it looks like a repository name (contains '/')
    repo_name = args[:repo_name] || (ARGV[1]&.include?('/') ? ARGV[1] : nil)
    
    unless repo_name
      puts "Error: Repository name is required"
      puts "Usage: rake sync:repository[owner/repo]"
      puts "   or: rake sync:repository owner/repo"
      puts "Example: rake sync:repository[rails/rails]"
      puts "     or: rake sync:repository rails/rails"
      exit 1
    end
    
    unless ENV['GITHUB_ACCESS_TOKEN']
      puts "Error: GITHUB_ACCESS_TOKEN environment variable is not set"
      puts "Please set your GitHub personal access token:"
      puts "  export GITHUB_ACCESS_TOKEN=your_token_here"
      exit 1
    end
    
    fetch_all = ENV['FETCH_ALL'] == 'true'
    
    puts "Starting unified sync for #{repo_name}"
    puts "Mode: #{fetch_all ? 'Full sync (all PRs)' : 'Incremental sync (recent updates only)'}"
    puts "=" * 60
    
    begin
      service = UnifiedSyncService.new(repo_name, fetch_all: fetch_all)
      service.sync!
    rescue => e
      puts "\nError during sync: #{e.message}"
      puts "Please check the logs for more details."
      exit 1
    end
  end
  
  desc "Unified sync with background job (async)"
  task :repository_async, [:repo_name] => :environment do |t, args|
    # Handle both bracketed and non-bracketed syntax
    # Only use ARGV if it looks like a repository name (contains '/')
    repo_name = args[:repo_name] || (ARGV[1]&.include?('/') ? ARGV[1] : nil)
    
    unless repo_name
      puts "Error: Repository name is required"
      puts "Usage: rake sync:repository_async[owner/repo]"
      puts "   or: rake sync:repository_async owner/repo"
      exit 1
    end
    
    unless ENV['GITHUB_ACCESS_TOKEN']
      puts "Error: GITHUB_ACCESS_TOKEN environment variable is not set"
      exit 1
    end
    
    fetch_all = ENV['FETCH_ALL'] == 'true'
    
    # Create/update repository record
    repository = Repository.find_or_create_by(name: repo_name)
    
    # Queue the unified sync job
    job_id = UnifiedSyncJob.perform_later(repo_name, fetch_all: fetch_all).job_id
    
    puts "Queued unified sync job for #{repo_name}"
    puts "Job ID: #{job_id}"
    puts "Mode: #{fetch_all ? 'Full sync' : 'Incremental sync'}"
    puts "Check Sidekiq dashboard or logs for progress"
  end
  
  desc "Check sync status for a repository"
  task :status, [:repo_name] => :environment do |t, args|
    # Handle both bracketed and non-bracketed syntax
    # Only use ARGV if it looks like a repository name (contains '/')
    repo_name = args[:repo_name] || (ARGV[1]&.include?('/') ? ARGV[1] : nil)
    
    unless repo_name
      puts "Error: Repository name is required"
      puts "Usage: rake sync:status[owner/repo]"
      puts "   or: rake sync:status owner/repo"
      exit 1
    end
    
    repository = Repository.find_by(name: repo_name)
    
    unless repository
      puts "Repository #{repo_name} not found"
      exit 1
    end
    
    puts "Repository: #{repository.name}"
    puts "Sync Status: #{repository.sync_status || 'never synced'}"
    
    if repository.sync_started_at
      puts "Started: #{repository.sync_started_at.strftime('%Y-%m-%d %H:%M:%S')}"
    end
    
    if repository.sync_completed_at
      puts "Completed: #{repository.sync_completed_at.strftime('%Y-%m-%d %H:%M:%S')}"
    end
    
    if repository.sync_progress
      puts "Progress: #{repository.sync_progress}%"
    end
    
    if repository.last_sync_error
      puts "Last Error: #{repository.last_sync_error}"
    end
    
    if repository.last_fetched_at
      puts "Last Fetched: #{repository.last_fetched_at.strftime('%Y-%m-%d %H:%M:%S')}"
    end
    
    puts "\nStatistics:"
    puts "  Pull Requests: #{repository.pull_requests.count}"
    puts "  Weeks: #{repository.weeks.count}"
    puts "  Reviews: #{Review.joins(pull_request: :repository).where(pull_requests: { repository_id: repository.id }).count}"
  end
  
  desc "List all repositories and their sync status"
  task list: :environment do
    repositories = Repository.order(:name)
    
    if repositories.empty?
      puts "No repositories found"
      exit 0
    end
    
    puts "%-40s %-15s %-20s %-10s" % ["Repository", "Status", "Last Sync", "Progress"]
    puts "-" * 90
    
    repositories.each do |repo|
      last_sync = repo.sync_completed_at ? repo.sync_completed_at.strftime('%Y-%m-%d %H:%M') : 'Never'
      progress = repo.sync_status == 'in_progress' ? "#{repo.sync_progress || 0}%" : '-'
      
      puts "%-40s %-15s %-20s %-10s" % [
        repo.name,
        repo.sync_status || 'never synced',
        last_sync,
        progress
      ]
    end
  end
end