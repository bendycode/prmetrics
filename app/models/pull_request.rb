class PullRequest < ApplicationRecord
  include WeekdayHours

  belongs_to :repository
  belongs_to :author, class_name: 'Contributor'
  belongs_to :ready_for_review_week, class_name: 'Week', optional: true
  belongs_to :first_review_week, class_name: 'Week', optional: true
  belongs_to :merged_week, class_name: 'Week', optional: true
  belongs_to :closed_week, class_name: 'Week', optional: true

  has_many :reviews, dependent: :destroy
  has_many :pull_request_users, dependent: :destroy
  has_many :contributors, through: :pull_request_users, source: :user

  validates :number, presence: true
  validates :title, presence: true
  validates :state, presence: true

  after_destroy :cleanup_orphaned_contributor
  after_save :update_week_associations_if_needed, unless: :skip_week_association_update

  # Original method that doesn't exclude weekends
  def raw_time_to_first_review
    return nil unless ready_for_review_at

    first_review = valid_first_review
    return nil unless first_review

    # Return in hours instead of seconds for consistency
    (first_review.submitted_at - ready_for_review_at) / 1.hour
  end

  # New method that excludes weekends
  def time_to_first_review
    return nil unless ready_for_review_at

    first_review = valid_first_review
    return nil unless first_review

    # Call the method from the WeekdayHours module directly
    WeekdayHours.weekday_hours_between(ready_for_review_at, first_review.submitted_at) * 1.hour
  end

  # New method for weekday hours to merge
  def weekday_hours_to_merge
    return nil unless ready_for_review_at && gh_merged_at

    # Call the method from the WeekdayHours module directly
    WeekdayHours.weekday_hours_between(ready_for_review_at, gh_merged_at) * 1.hour
  end

  def valid_first_review
    return nil unless ready_for_review_at

    # Only consider reviews that occurred after ready_for_review_at
    reviews
      .where('submitted_at > ?', ready_for_review_at)
      .order(:submitted_at)
      .first
  end

  def update_week_associations
    self.ready_for_review_week = Week.find_by_date(ready_for_review_at)

    # Find first valid review after ready_for_review_at
    first_valid_review = valid_first_review

    self.first_review_week = Week.find_by_date(first_valid_review&.submitted_at)
    self.merged_week = Week.find_by_date(gh_merged_at)
    self.closed_week = Week.find_by_date(gh_closed_at)
    save
  end

  def skip_week_association_update
    @skip_week_association_update || false
  end

  def skip_week_association_update!
    @skip_week_association_update = true
  end

  private

  def update_week_associations_if_needed
    # Only update if lifecycle dates changed to avoid unnecessary work
    if saved_change_to_ready_for_review_at? || 
       saved_change_to_gh_merged_at? || 
       saved_change_to_gh_closed_at? ||
       saved_change_to_gh_created_at?
      update_week_associations
    end
  end

  def cleanup_orphaned_contributor
    return unless author
    
    # Only delete Contributor if they have no other authored pull requests
    # Don't delete based on reviews or pull_request_users since those are
    # participation records that shouldn't cause deletion
    if author.authored_pull_requests.empty?
      author.destroy
    end
  end
end
