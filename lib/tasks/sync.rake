# Define a rule to handle repository names as tasks
rule(/\A[a-zA-Z0-9._-]+\/[a-zA-Z0-9._-]+\z/) do |t|
  # No-op rule to consume repository name arguments
end

namespace :sync do
  desc "Unified sync: fetch PRs, generate weeks, and update stats with real-time progress"
  task :repository, [:repo_name] => :environment do |t, args|
    # Handle both bracketed and non-bracketed syntax
    # Only use ARGV if it looks like a repository name (owner/repo format, no special chars)
    argv_repo = ARGV[1] if ARGV[1] && ARGV[1].match?(/\A[a-zA-Z0-9._-]+\/[a-zA-Z0-9._-]+\z/)
    repo_name = args[:repo_name] || argv_repo

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
    # Only use ARGV if it looks like a repository name (owner/repo format, no special chars)
    argv_repo = ARGV[1] if ARGV[1] && ARGV[1].match?(/\A[a-zA-Z0-9._-]+\/[a-zA-Z0-9._-]+\z/)
    repo_name = args[:repo_name] || argv_repo

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
    Repository.find_or_create_by(name: repo_name)

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
    # Only use ARGV if it looks like a repository name (owner/repo format, no special chars)
    argv_repo = ARGV[1] if ARGV[1] && ARGV[1].match?(/\A[a-zA-Z0-9._-]+\/[a-zA-Z0-9._-]+\z/)
    repo_name = args[:repo_name] || argv_repo

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

  desc "Sync all repositories with incremental updates (for nightly cron jobs)"
  task all_repositories: :environment do
    unless ENV['GITHUB_ACCESS_TOKEN']
      puts "Error: GITHUB_ACCESS_TOKEN environment variable is not set"
      puts "Please set your GitHub personal access token:"
      puts "  export GITHUB_ACCESS_TOKEN=your_token_here"
      exit 1
    end

    fetch_all = ENV['FETCH_ALL'] == 'true'
    repositories = Repository.order(:name)

    if repositories.empty?
      puts "No repositories found to sync"
      exit 0
    end

    puts "Starting sync for all repositories"
    puts "Mode: #{fetch_all ? 'Full sync (all PRs)' : 'Incremental sync (recent updates only)'}"
    puts "Repositories to sync: #{repositories.count}"
    puts "=" * 80

    total_repos = repositories.count
    success_count = 0
    error_count = 0
    start_time = Time.current

    repositories.each_with_index do |repository, index|
      repo_start_time = Time.current

      puts "\n[#{index + 1}/#{total_repos}] Syncing #{repository.name}..."

      begin
        service = UnifiedSyncService.new(repository.name, fetch_all: fetch_all)
        service.sync!

        repo_duration = Time.current - repo_start_time
        success_count += 1

        puts "  ✓ Completed #{repository.name} in #{repo_duration.round(2)}s"

      rescue => e
        repo_duration = Time.current - repo_start_time
        error_count += 1

        puts "  ✗ Failed #{repository.name} after #{repo_duration.round(2)}s: #{e.message}"
        Rails.logger.error "Sync failed for #{repository.name}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")

        # Continue with next repository instead of exiting
      end
    end

    total_duration = Time.current - start_time

    puts "\n" + "=" * 80
    puts "Sync Summary:"
    puts "  Total repositories: #{total_repos}"
    puts "  Successful: #{success_count}"
    puts "  Failed: #{error_count}"
    puts "  Total time: #{total_duration.round(2)}s"
    puts "  Average time per repo: #{(total_duration / total_repos).round(2)}s"

    if error_count > 0
      puts "\nWarning: #{error_count} repositories failed to sync. Check logs for details."
      exit 1
    else
      puts "\nAll repositories synced successfully!"
    end
  end
end
