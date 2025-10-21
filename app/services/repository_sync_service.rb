class RepositorySyncService
  attr_reader :repository, :fetch_all

  def initialize(repository, fetch_all: false)
    @repository = repository
    @fetch_all = fetch_all
  end

  def perform
    if should_use_batch_sync?
      # Large repos or first sync - use batch processing
      start_batch_sync
    else
      # Small incremental update - use original job
      start_regular_sync
    end
  end

  private

  def should_use_batch_sync?
    # Always use batch sync for now
    # This ensures we don't hit timeouts and have better progress tracking
    true
  end

  def known_large_repository?
    # List of known large repos that should always use batch
    large_repos = [
      'rails/rails',
      'facebook/react',
      'microsoft/vscode',
      'kubernetes/kubernetes'
    ]

    large_repos.include?(repository.name.downcase)
  end

  def start_batch_sync
    Rails.logger.info "Starting batch sync for #{repository.name}"
    SyncRepositoryBatchJob.perform_later(repository.name, page: 1, fetch_all: fetch_all)
  end

  def start_regular_sync
    Rails.logger.info "Starting regular sync for #{repository.name}"
    SyncRepositoryJob.perform_later(repository.name, fetch_all: fetch_all)
  end
end
