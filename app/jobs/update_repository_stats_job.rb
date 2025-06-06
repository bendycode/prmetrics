class UpdateRepositoryStatsJob < ApplicationJob
  queue_as :low
  
  def perform(repository_id)
    repository = Repository.find(repository_id)
    
    # Generate/update week records
    WeekStatsService.generate_weeks_for_repository(repository)
    
    # Update stats for all weeks of this repository
    repository.weeks.find_each do |week|
      WeekStatsService.new(week).update_stats
    end
    
    # Clean up orphaned data
    cleanup_orphaned_data(repository)
    
    Rails.logger.info "Updated stats for #{repository.name}"
  end
  
  private
  
  def cleanup_orphaned_data(repository)
    # Remove reviews for PRs that no longer exist
    repository.pull_requests.joins(:reviews).where(reviews: { pull_request_id: nil }).destroy_all
  end
end