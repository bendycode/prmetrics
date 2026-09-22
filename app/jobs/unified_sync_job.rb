class UnifiedSyncJob < ApplicationJob
  queue_as :default

  # A record that fails validation fails the same way on every attempt, and a
  # retry starts the sync over from its first page. UnifiedSyncService has
  # already recorded the failure on the repository. A uniqueness failure is
  # the exception: it means an overlapping sync stored the row first, so a
  # retry finds that row and succeeds.
  discard_on ActiveRecord::RecordInvalid do |_job, error|
    raise error if error.record.errors.any? { |detail| detail.type == :taken }
  end

  def perform(repository, fetch_all: false)
    logger.info "Starting unified sync for #{repository.name} (#{fetch_all ? 'full' : 'incremental'})"

    service = UnifiedSyncService.new(
      repository.name,
      fetch_all: fetch_all,
      progress_callback: ->(message) { logger.info "[UnifiedSync] #{message}" }
    )
    service.sync!

    # The sync refreshes only the weeks its pull requests touched; a queued
    # sync also rebuilds every week, as rake weeks:update_stats does.
    UpdateRepositoryStatsJob.perform_later(service.repository.id)

    logger.info "Unified sync completed for #{repository.name}"
  end
end
