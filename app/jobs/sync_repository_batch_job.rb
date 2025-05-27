class SyncRepositoryBatchJob < ApplicationJob
  queue_as :default
  
  BATCH_SIZE = 100
  
  def perform(repository_name, page: 1, fetch_all: false)
    repository = Repository.find_by!(name: repository_name)
    
    # Mark as in progress on first page
    if page == 1
      repository.update!(
        sync_status: 'in_progress',
        sync_started_at: Time.current,
        last_sync_error: nil
      )
    end
    
    service = GithubService.new(ENV['GITHUB_ACCESS_TOKEN'])
    
    # Fetch one page of PRs
    pull_requests = fetch_pull_requests_page(service, repository, page)
    
    if pull_requests.empty?
      # We've reached the end
      finalize_sync(repository)
    else
      # Process this batch
      process_pull_requests(service, repository, pull_requests)
      
      # Update progress
      update_progress(repository, page, pull_requests.size)
      
      # Check if we should continue
      if should_continue_fetching?(repository, pull_requests, fetch_all)
        # Queue next page
        SyncRepositoryBatchJob.perform_later(repository_name, page: page + 1, fetch_all: fetch_all)
      else
        finalize_sync(repository)
      end
    end
  rescue => e
    handle_sync_error(repository, e)
    raise # Re-raise to trigger Sidekiq retry
  end
  
  private
  
  def fetch_pull_requests_page(service, repository, page)
    client = service.send(:client)
    client.pull_requests(
      repository.name,
      state: 'all',
      per_page: BATCH_SIZE,
      page: page,
      sort: 'updated',
      direction: 'desc'
    )
  end
  
  def process_pull_requests(service, repository, pull_requests)
    pull_requests.each do |pr_data|
      # Process each PR (existing logic from GithubService)
      service.send(:process_pull_request, repository, pr_data)
    end
  end
  
  def update_progress(repository, page, batch_size)
    total_processed = (page - 1) * BATCH_SIZE + batch_size
    Rails.logger.info "Processed page #{page} for #{repository.name} (#{total_processed} PRs so far)"
    
    # Optionally store progress
    repository.update_column(:sync_progress, total_processed)
  end
  
  def should_continue_fetching?(repository, pull_requests, fetch_all)
    return false if pull_requests.size < BATCH_SIZE # Last page
    
    if fetch_all
      true
    else
      # Check if we've hit PRs we've already seen
      oldest_pr_date = pull_requests.last.updated_at
      repository.last_fetched_at.nil? || oldest_pr_date > repository.last_fetched_at
    end
  end
  
  def finalize_sync(repository)
    repository.update!(
      sync_status: 'completed',
      sync_completed_at: Time.current,
      last_fetched_at: Time.current
    )
    
    # Queue stats calculation
    UpdateRepositoryStatsJob.perform_later(repository.id)
    
    Rails.logger.info "Completed sync for #{repository.name}"
  end
  
  def handle_sync_error(repository, error)
    repository.update!(
      sync_status: 'failed',
      last_sync_error: error.message
    )
    Rails.logger.error "Sync failed for #{repository.name}: #{error.message}"
  end
end