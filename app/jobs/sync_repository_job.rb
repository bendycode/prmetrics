class SyncRepositoryJob < ApplicationJob
  queue_as :default

  def perform(repo_name, fetch_all: false, access_token: nil)
    # Use provided token or fall back to environment variable
    token = access_token || ENV['GITHUB_ACCESS_TOKEN']

    unless token
      Rails.logger.error "No GitHub access token available for sync"
      return
    end

    # Update repository status to indicate sync is in progress
    repository = Repository.find_or_create_by(name: repo_name)
    repository.update(sync_status: 'in_progress', sync_started_at: Time.current)

    begin
      # Perform the sync
      service = GithubService.new(token)
      service.fetch_and_store_pull_requests(repo_name, fetch_all: fetch_all)

      # Update status to completed
      repository.update(
        sync_status: 'completed',
        sync_completed_at: Time.current,
        last_sync_error: nil
      )
    rescue => e
      Rails.logger.error "Repository sync failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      # Update status to failed
      repository.update(
        sync_status: 'failed',
        sync_completed_at: Time.current,
        last_sync_error: e.message
      )

      # Re-raise to trigger Sidekiq retry
      raise
    end
  end
end
