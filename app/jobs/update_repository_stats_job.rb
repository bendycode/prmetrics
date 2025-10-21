class UpdateRepositoryStatsJob < ApplicationJob
  queue_as :low

  def perform(repository_id)
    repository = Repository.find(repository_id)

    # Generate/update week records for ALL repositories (not just the synced one)
    # This ensures that cross-repository week calculations are up to date
    Repository.find_each do |repo|
      WeekStatsService.generate_weeks_for_repository(repo)
    end

    # Update statistics for ALL weeks across ALL repositories
    # This makes sync buttons equivalent to running `rake weeks:update_stats`
    WeekStatsService.update_all_weeks

    # Clean up orphaned data for the synced repository
    cleanup_orphaned_data(repository)

    Rails.logger.info "Updated stats for #{repository.name} and all related repositories"
  end

  private

  def cleanup_orphaned_data(repository)
    # Remove reviews for PRs that no longer exist
    repository.pull_requests.joins(:reviews).where(reviews: { pull_request_id: nil }).destroy_all
  end
end
