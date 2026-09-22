class UnifiedSyncJob < ApplicationJob
  queue_as :default

  def perform(repository, fetch_all: false)
    logger.info "Starting unified sync for #{repository.name} (#{fetch_all ? 'full' : 'incremental'})"

    service = UnifiedSyncService.new(
      repository.name,
      fetch_all: fetch_all,
      progress_callback: ->(message) { logger.info "[UnifiedSync] #{message}" }
    )
    service.sync!

    # The sync refreshes only the weeks its pull requests touched; a sync
    # started from the app also rebuilds every week, as rake weeks:update_stats does.
    UpdateRepositoryStatsJob.perform_later(service.repository.id)

    logger.info "Unified sync completed for #{repository.name}"
  end
end
