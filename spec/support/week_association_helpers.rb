module WeekAssociationHelpers
  def without_week_association_callbacks
    # Temporarily disable callbacks for testing
    old_skip_pr = PullRequest.skip_callback(:save, :after, :update_week_associations_if_needed)
    old_skip_review_save = Review.skip_callback(:save, :after, :update_pull_request_first_review_week)
    old_skip_review_destroy = Review.skip_callback(:destroy, :after, :update_pull_request_first_review_week)
    
    yield
    
  ensure
    # Re-enable callbacks
    PullRequest.set_callback(:save, :after, :update_week_associations_if_needed) unless old_skip_pr
    Review.set_callback(:save, :after, :update_pull_request_first_review_week) unless old_skip_review_save
    Review.set_callback(:destroy, :after, :update_pull_request_first_review_week) unless old_skip_review_destroy
  end
end

RSpec.configure do |config|
  config.include WeekAssociationHelpers
end