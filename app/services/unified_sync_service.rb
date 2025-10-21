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
    github_service = GithubService.new(ENV.fetch('GITHUB_ACCESS_TOKEN', nil))

    # Get total count for progress tracking
    @total_prs = estimate_total_prs(github_service)
    log_progress("Estimated #{@total_prs} pull requests to process")

    # Step 1: Fetch PRs with our custom processor
    github_service.fetch_and_store_pull_requests(
      @repo_name,
      fetch_all: @fetch_all,
      processor: method(:process_pull_request)
    )

    # Step 2: Fetch recent review activity (only for incremental sync)
    # This catches PRs that got new reviews but weren't updated themselves
    return if @fetch_all

    log_progress("Fetching recent review activity...")
    review_comments_processed = github_service.fetch_recent_review_activity(@repo_name)
    log_progress("Processed #{review_comments_processed} recent review comments")
  end

  def process_pull_request(pr_data)
    # Process the PR (this happens in GithubService)
    # but we hook into it to track progress and create weeks

    @processed_prs += 1

    # Extract the PR that was just created/updated
    pr_number = pr_data.number
    pull_request = @repository.pull_requests.find_by(number: pr_number)

    if pull_request
      # Create week records and update associations for this PR
      pull_request.ensure_weeks_exist_and_update_associations

      # Track created weeks
      track_created_weeks(pull_request)

      # Update progress
      update_progress
    end

    # Log progress every 10 PRs or for the last one
    return unless @processed_prs % 10 == 0 || @processed_prs == @total_prs

    log_progress("Processed #{@processed_prs} pull requests...")
  end

  def track_created_weeks(pull_request)
    # Track all weeks associated with this PR for stats update
    weeks = [
      pull_request.ready_for_review_week,
      pull_request.first_review_week,
      pull_request.merged_week,
      pull_request.closed_week
    ].compact.uniq

    weeks.each do |week|
      if week.created_at >= 1.minute.ago && !@created_weeks.include?(week)
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
