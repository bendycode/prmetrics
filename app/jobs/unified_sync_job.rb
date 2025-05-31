class UnifiedSyncJob < ApplicationJob
  queue_as :default
  
  def perform(repo_name, fetch_all: false)
    # Log to Sidekiq output
    logger.info "Starting unified sync for #{repo_name} (#{fetch_all ? 'full' : 'incremental'})"
    
    # Create service with a logger-based progress callback
    service = UnifiedSyncService.new(
      repo_name, 
      fetch_all: fetch_all,
      progress_callback: ->(message) { logger.info "[UnifiedSync] #{message}" }
    )
    
    # Perform the sync
    service.sync!
    
    logger.info "Unified sync completed for #{repo_name}"
  end
end