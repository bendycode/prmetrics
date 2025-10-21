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

  validates :number, presence: true, uniqueness: { scope: :repository_id }
  validates :title, presence: true
  validates :state, presence: true

  # Scopes for querying approved/open/unmerged PRs
  scope :approved, lambda {
    joins(:reviews).merge(Review.approved).distinct
  }

  scope :open_at, lambda { |timestamp|
    where('gh_created_at <= ?', timestamp)
      .where('(gh_closed_at IS NULL OR gh_closed_at > ?)', timestamp)
  }

  scope :unmerged, lambda {
    where(gh_merged_at: nil)
  }

  scope :unmerged_at, lambda { |timestamp|
    where('(gh_merged_at IS NULL OR gh_merged_at > ?)', timestamp)
  }

  # Prevent cross-repository week associations
  validate :weeks_belong_to_same_repository

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

  # Calculate days since first approval relative to a reference date
  # @param reference_date [Time/Date] The date to calculate from (defaults to current time)
  # @return [Integer] Number of days since first approval, or 0 if no approved reviews
  def days_since_first_approval(reference_date = Time.current)
    first_approved_review = reviews
                            .where(state: 'APPROVED')
                            .order(:submitted_at)
                            .first

    return 0 unless first_approved_review

    # Use end_of_day for reference_date to be consistent with week boundaries
    reference_timestamp = reference_date.in_time_zone.end_of_day
    ((reference_timestamp - first_approved_review.submitted_at) / 1.day).to_i
  end

  def update_week_associations
    # Use repository-scoped week lookups to prevent cross-repository associations
    self.ready_for_review_week = repository.weeks.find_by_date(ready_for_review_at)

    # Find first valid review after ready_for_review_at
    first_valid_review = valid_first_review

    self.first_review_week = repository.weeks.find_by_date(first_valid_review&.submitted_at)
    self.merged_week = repository.weeks.find_by_date(gh_merged_at)
    self.closed_week = repository.weeks.find_by_date(gh_closed_at)
    save
  end

  def ensure_weeks_exist_and_update_associations
    # First ensure all required weeks exist
    dates = [ready_for_review_at, valid_first_review&.submitted_at, gh_merged_at, gh_closed_at].compact

    dates.each do |date|
      ct_date = date.in_time_zone('America/Chicago')
      week_number = ct_date.strftime('%Y%W').to_i

      repository.weeks.find_or_create_by(week_number: week_number) do |w|
        w.begin_date = ct_date.beginning_of_week.to_date
        w.end_date = ct_date.end_of_week.to_date
      end
    end

    # Now update associations - weeks will exist
    update_week_associations
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
    return unless author.authored_pull_requests.empty?

    author.destroy
  end

  def weeks_belong_to_same_repository
    week_associations = {
      ready_for_review_week: ready_for_review_week,
      first_review_week: first_review_week,
      merged_week: merged_week,
      closed_week: closed_week
    }

    week_associations.each do |association_name, week|
      if week && week.repository_id != repository_id
        errors.add(association_name, 'must belong to the same repository as the pull request')
      end
    end
  end
end
