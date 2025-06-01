class UnifiedSyncService
  attr_reader :repository, :progress_callback
  
  def initialize(repo_name, fetch_all: false, progress_callback: nil)
    @repo_name = repo_name
    @fetch_all = fetch_all
    @progress_callback = progress_callback || method(:default_progress_callback)
    @repository = Repository.find_or_create_by(name: repo_name)
    @processed_prs = 0
    @created_weeks = Set.new
    @updated_weeks = Set.new
  end
  
  def sync!
    log_progress("Starting unified sync for #{@repo_name}")
    
    # Mark sync as in progress
    @repository.update(
      sync_status: 'in_progress',
      sync_started_at: Time.current,
      sync_progress: 0
    )
    
    begin
      # Fetch and process PRs with real-time updates
      fetch_and_process_pull_requests
      
      # Final stats update for all affected weeks
      update_week_statistics
      
      # Mark sync as completed
      @repository.update(
        sync_status: 'completed',
        sync_completed_at: Time.current,
        last_sync_error: nil,
        sync_progress: 100
      )
      
      log_progress("Sync completed successfully!")
      log_summary
      
    rescue => e
      Rails.logger.error "Unified sync failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      @repository.update(
        sync_status: 'failed',
        sync_completed_at: Time.current,
        last_sync_error: e.message
      )
      
      raise
    end
  end
  
  private
  
  def fetch_and_process_pull_requests
    github_service = GithubService.new(ENV['GITHUB_ACCESS_TOKEN'])
    
    # Get total count for progress tracking
    @total_prs = estimate_total_prs(github_service)
    log_progress("Estimated #{@total_prs} pull requests to process")
    
    # Fetch PRs with our custom processor
    github_service.fetch_and_store_pull_requests(
      @repo_name,
      fetch_all: @fetch_all,
      processor: method(:process_pull_request)
    )
  end
  
  def process_pull_request(pr_data)
    # Process the PR (this happens in GithubService)
    # but we hook into it to track progress and create weeks
    
    @processed_prs += 1
    
    # Extract the PR that was just created/updated
    pr_number = pr_data.number
    pull_request = @repository.pull_requests.find_by(number: pr_number)
    
    if pull_request
      # Create week records for this PR's lifecycle dates
      create_weeks_for_pull_request(pull_request)
      
      # Update progress
      update_progress
    end
    
    # Log progress every 10 PRs or for the last one
    if @processed_prs % 10 == 0 || @processed_prs == @total_prs
      log_progress("Processed #{@processed_prs} pull requests...")
    end
  end
  
  def create_weeks_for_pull_request(pull_request)
    dates = [
      pull_request.gh_created_at,
      pull_request.ready_for_review_at,
      pull_request.gh_merged_at,
      pull_request.gh_closed_at
    ].compact
    
    dates.each do |date|
      # Convert to Central Time for consistent week calculation
      ct_date = date.in_time_zone("America/Chicago")
      week_number = ct_date.strftime('%Y%W').to_i
      
      week = @repository.weeks.find_or_create_by(week_number: week_number) do |w|
        w.begin_date = ct_date.beginning_of_week.to_date
        w.end_date = ct_date.end_of_week.to_date
      end
      
      if week.previously_new_record?
        @created_weeks << week
        log_progress("Created week #{week.begin_date.strftime('%Y-%m-%d')} (CT)")
      end
      
      @updated_weeks << week
    end
  end
  
  def update_week_statistics
    log_progress("Updating statistics for #{@updated_weeks.size} weeks...")
    
    @updated_weeks.each_with_index do |week, index|
      WeekStatsService.new(week).update_stats
      
      # Show progress for stats update
      progress = ((index + 1).to_f / @updated_weeks.size * 100).round
      @repository.update_column(:sync_progress, 90 + (progress * 0.1)) # Last 10% for stats
      
      if (index + 1) % 5 == 0 || index == @updated_weeks.size - 1
        log_progress("Updated statistics for #{index + 1}/#{@updated_weeks.size} weeks")
      end
    end
  end
  
  def estimate_total_prs(github_service)
    # Get a rough count of PRs to sync
    # This is an estimate for progress tracking
    if @fetch_all
      # For full sync, get total count from GitHub
      github_service.get_pull_request_count(@repo_name)
    else
      # For incremental sync, estimate based on time since last sync
      days_since_sync = @repository.last_fetched_at ? 
        ((Time.current - @repository.last_fetched_at) / 1.day).round : 30
      
      # Rough estimate: 2 PRs per day
      [days_since_sync * 2, 10].max
    end
  rescue => e
    Rails.logger.warn "Could not estimate PR count: #{e.message}"
    100 # Default estimate
  end
  
  def update_progress
    # Update progress (0-90% for PR fetching, 90-100% for stats)
    progress = [(@processed_prs.to_f / @total_prs * 90).round, 90].min
    @repository.update_column(:sync_progress, progress)
  end
  
  def log_progress(message)
    @progress_callback.call(message)
    Rails.logger.info "[UnifiedSync] #{message}"
  end
  
  def log_summary
    log_progress("=" * 50)
    log_progress("Sync Summary:")
    log_progress("  - Processed #{@processed_prs} pull requests")
    log_progress("  - Created #{@created_weeks.size} new week records")
    log_progress("  - Updated statistics for #{@updated_weeks.size} weeks")
    log_progress("=" * 50)
  end
  
  def default_progress_callback(message)
    puts "[#{Time.current.strftime('%H:%M:%S')}] #{message}"
  end
end