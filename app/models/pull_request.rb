class PullRequest < ApplicationRecord
  include WeekdayHours

  # Every week a pull request points at; Week.unreferenced reads them all
  WEEK_COLUMNS = %i[ready_for_review_week_id first_review_week_id first_approval_week_id
                    merged_week_id closed_week_id].freeze

  belongs_to :repository
  belongs_to :author, class_name: 'Contributor'
  belongs_to :merged_by, class_name: 'Contributor', optional: true, inverse_of: :merged_pull_requests
  belongs_to :ready_for_review_week, class_name: 'Week', optional: true
  belongs_to :first_review_week, class_name: 'Week', optional: true
  belongs_to :first_approval_week, class_name: 'Week', optional: true
  belongs_to :merged_week, class_name: 'Week', optional: true
  belongs_to :closed_week, class_name: 'Week', optional: true

  has_many :reviews, dependent: :destroy
  has_many :pull_request_users, dependent: :destroy
  has_many :contributors, through: :pull_request_users, source: :user

  validates :number, presence: true, uniqueness: { scope: :repository_id }
  validates :title, presence: true
  validates :state, presence: true

  # Scopes for querying approved/open/unmerged PRs
  # id breaks ties: GitHub timestamps are second-precision, so pull requests
  # opened in the same second share a gh_created_at, and the index pages this
  # scope with LIMIT/OFFSET, where tied rows may come back in a different order
  # per query.
  scope :newest_first, -> { order(gh_created_at: :desc, id: :desc) }
  # Every development metric reads through this; see Repository#refresh_promotions!
  scope :development, -> { where(promotion: false) }
  scope :promotions, -> { where(promotion: true) }
  scope :merged, -> { where.not(gh_merged_at: nil) }
  scope :missing_merger, -> { merged.where(merged_by_id: nil) }
  scope :from_branch, ->(ref) { where(head_ref: ref) }
  scope :into_branch, ->(refs) { where(base_ref: refs) }
  # Cleared to merge by a person; a bot's approval is feedback, not approval.
  # A subquery rather than a join, so composing this with joins(:author) cannot
  # silently move the bot filter onto the pull request's own author.
  scope :approved, -> { where(id: Review.approved.by_people.select(:pull_request_id)) }

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

    WeekdayHours.weekday_hours_between(ready_for_review_at, gh_merged_at) * 1.hour
  end

  def weekday_hours_to_approval
    approved = approved_at
    return nil unless approved

    WeekdayHours.weekday_hours_between(ready_for_review_at, approved) * 1.hour
  end

  # When the pull request was cleared to merge: the first approval from a
  # person, or the author's own merge, whichever came first. An author merging
  # their own work is that pull request's approval, which is how a repository
  # where authors merge their own work gets an approval time at all.
  # An approval given while it was still a draft counts from the moment it
  # became ready for review, so nothing is approved before it was askable.
  def approved_at
    self.class.approval_time(first_approval_at, self_merged_at, ready_for_review_at)
  end

  # When it was cleared to merge, whether or not it had been marked ready for
  # review by then. Late and stale ask only how long it has waited since.
  def cleared_at
    [first_approval_at, self_merged_at].compact.min
  end

  # When each of these pull requests was approved, as {id => time}, in two
  # queries rather than one per pull request. One nobody cleared is absent.
  def self.approved_times
    approvals = Review.approved.by_people.where(pull_request_id: all)
                      .group(:pull_request_id).minimum(:submitted_at)
    candidates = where.not(ready_for_review_at: nil)
                      .pluck(:id, :ready_for_review_at, :gh_merged_at, :merged_by_id, :author_id)

    candidates.filter_map do |id, ready_at, merged_at, merged_by_id, author_id|
      self_merged_at = merged_by_id == author_id ? merged_at : nil
      approved_at = approval_time(approvals[id]&.in_time_zone, self_merged_at, ready_at)
      [id, approved_at] if approved_at
    end.to_h
  end

  # The wait from ready for review to approval for each of these pull
  # requests, as the pairs the weekday-hours math takes
  def self.approval_windows
    ready_times = where(id: approved_times.keys).pluck(:id, :ready_for_review_at).to_h
    approved_times.map { |id, approved_at| [ready_times[id], approved_at] }
  end

  # One arithmetic for both the per-record reader and the batch: the earlier of
  # a person's approval and the author's own merge, never before ready.
  def self.approval_time(first_approval_at, self_merged_at, ready_at)
    cleared = [first_approval_at, self_merged_at].compact.min
    [cleared, ready_at].max if cleared && ready_at
  end

  def valid_first_review_at
    valid_first_review&.submitted_at
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
    cleared = cleared_at
    return 0 unless cleared

    # Use end_of_day for reference_date to be consistent with week boundaries
    reference_timestamp = reference_date.in_time_zone.end_of_day
    ((reference_timestamp - cleared) / 1.day).to_i
  end

  def first_approval_at
    reviews.approved.by_people.minimum(:submitted_at)&.in_time_zone
  end

  # An author merging their own work is that pull request's approval, a bot's
  # own merge included: an update bot merging its own pull request has cleared
  # it, where a bot reviewing someone else's work has only answered.
  def self_merged_at
    gh_merged_at if merged_by_id && merged_by_id == author_id
  end

  def update_week_associations
    # Use repository-scoped week lookups to prevent cross-repository associations
    self.ready_for_review_week = repository.weeks.find_by_date(ready_for_review_at)

    # Find first valid review after ready_for_review_at
    first_valid_review = valid_first_review

    self.first_review_week = repository.weeks.find_by_date(first_valid_review&.submitted_at)
    self.first_approval_week = repository.weeks.find_by_date(approved_at)
    self.merged_week = repository.weeks.find_by_date(gh_merged_at)
    self.closed_week = repository.weeks.find_by_date(gh_closed_at)
    save
  end

  def ensure_weeks_exist_and_update_associations
    # First ensure all required weeks exist
    dates = [ready_for_review_at, valid_first_review&.submitted_at, approved_at, gh_merged_at, gh_closed_at].compact

    dates.each do |date|
      ct_date = date.in_time_zone('America/Chicago')
      week_begin = ct_date.beginning_of_week.to_date
      week_end = ct_date.end_of_week.to_date
      week_number = week_begin.strftime('%Y%W').to_i

      repository.weeks.find_or_create_by(week_number: week_number) do |w|
        w.begin_date = week_begin
        w.end_date = week_end
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
    # merged_by decides whether a merge was the author's own, which is what
    # gives a self-merged pull request its approval week
    if saved_change_to_ready_for_review_at? ||
       saved_change_to_gh_merged_at? ||
       saved_change_to_gh_closed_at? ||
       saved_change_to_gh_created_at? ||
       saved_change_to_merged_by_id? ||
       saved_change_to_author_id?
      update_week_associations
    end
  end

  def cleanup_orphaned_contributor
    return unless author

    # Only delete Contributor if they have no other authored pull requests and
    # merged none. Don't delete based on reviews or pull_request_users since
    # those are participation records that shouldn't cause deletion
    return unless author.authored_pull_requests.empty? && author.merged_pull_requests.empty?

    author.destroy
  end

  def weeks_belong_to_same_repository
    week_associations = {
      ready_for_review_week: ready_for_review_week,
      first_review_week: first_review_week,
      first_approval_week: first_approval_week,
      merged_week: merged_week,
      closed_week: closed_week
    }

    week_associations.each do |association_name, week|
      if week && week.repository_id != repository_id
        errors.add(association_name,
                   'must belong to the same repository as the pull request')
      end
    end
  end
end
