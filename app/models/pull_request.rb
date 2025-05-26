class PullRequest < ApplicationRecord
  include WeekdayHours

  belongs_to :repository
  belongs_to :author, class_name: 'GithubUser'
  belongs_to :ready_for_review_week, class_name: 'Week', optional: true
  belongs_to :first_review_week, class_name: 'Week', optional: true
  belongs_to :merged_week, class_name: 'Week', optional: true
  belongs_to :closed_week, class_name: 'Week', optional: true

  has_many :reviews, dependent: :destroy
  has_many :pull_request_users, dependent: :destroy
  has_many :users, through: :pull_request_users

  validates :number, presence: true
  validates :title, presence: true
  validates :state, presence: true

  after_destroy :cleanup_orphaned_github_user

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

  private

  def cleanup_orphaned_github_user
    return unless author
    
    # Only delete GithubUser if they have no other pull requests
    if author.authored_pull_requests.empty?
      author.destroy
    end
  end
end
