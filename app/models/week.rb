class Week < ApplicationRecord
  belongs_to :repository

  has_many :ready_for_review_prs, class_name: 'PullRequest', foreign_key: 'ready_for_review_week_id'
  has_many :first_review_prs, class_name: 'PullRequest', foreign_key: 'first_review_week_id'
  has_many :merged_prs, class_name: 'PullRequest', foreign_key: 'merged_week_id'
  has_many :closed_prs, class_name: 'PullRequest', foreign_key: 'closed_week_id'

  validates :week_number, presence: true, uniqueness: { scope: :repository_id }
  validates :begin_date, :end_date, presence: true

  scope :ordered, -> { order(begin_date: :desc) }

  def self.find_by_date(date)
    return nil unless date
    where('begin_date <= ? AND end_date >= ?', date, date).first
  end

  def previous_week
    repository.weeks.where('begin_date < ?', begin_date).order(begin_date: :desc).first
  end

  def next_week
    repository.weeks.where('begin_date > ?', begin_date).order(:begin_date).first
  end

  def open_prs
    end_time = Time.zone.local(end_date.year, end_date.month, end_date.day, 23, 59, 59)
    repository.pull_requests
      .where(draft: false)
      .where('gh_created_at <= ? AND (gh_closed_at > ? OR gh_closed_at IS NULL)',
            end_time,
            end_time)
  end

  def draft_prs
    end_time = Time.zone.local(end_date.year, end_date.month, end_date.day, 23, 59, 59)
    repository.pull_requests
      .where(draft: true)
      .where('gh_created_at <= ? AND (gh_closed_at > ? OR gh_closed_at IS NULL)',
            end_time,
            end_time)
  end

  def started_prs
    repository.pull_requests.where(gh_created_at: begin_date.in_time_zone.beginning_of_day..end_date.in_time_zone.end_of_day)
  end

  def cancelled_prs
    closed_prs.where(gh_merged_at: nil)
  end

  def avg_hours_to_first_review
    # Modified to ensure we only consider reviews that come AFTER ready_for_review_at
    prs_with_first_review = repository.pull_requests
      .joins(:reviews)
      .where(reviews: { submitted_at: begin_date..end_date })
      .where.not(pull_requests: { ready_for_review_at: nil })
      .where('reviews.submitted_at > pull_requests.ready_for_review_at')
      .group('pull_requests.id')
      .having(
        'MIN(CASE WHEN reviews.submitted_at > pull_requests.ready_for_review_at
              THEN reviews.submitted_at END) BETWEEN ? AND ?',
        begin_date,
        end_date
      )
      .select(
        'pull_requests.id,
         pull_requests.ready_for_review_at,
         MIN(CASE WHEN reviews.submitted_at > pull_requests.ready_for_review_at
             THEN reviews.submitted_at END) AS first_review_at'
      )

    total_hours = prs_with_first_review.sum do |pr|
      ((pr.first_review_at - pr.ready_for_review_at) / 1.hour).round(2)
    end

    count = prs_with_first_review.length
    count > 0 ? (total_hours / count).round(2) : nil
  end

  def avg_hours_to_merge
    merged_prs.where.not(ready_for_review_at: nil)
              .average("EXTRACT(EPOCH FROM (gh_merged_at - ready_for_review_at)) / 3600")
              &.round(2)
  end
end
