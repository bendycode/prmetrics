class Week < ApplicationRecord
  include WeekdayHours

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
    # Convert to date for consistent lookup - use the date in the original timezone
    # to avoid edge cases where timezone conversion changes the date
    lookup_date = date.respond_to?(:to_date) ? date.to_date : date
    where('begin_date <= ? AND end_date >= ?', lookup_date, lookup_date).first
  end
  
  # Find or create week for a specific repository and week number
  # This ensures we never get weeks from other repositories
  def self.for_repository_and_week_number(repository, week_number)
    return nil unless repository && week_number
    
    repository.weeks.find_or_create_by(week_number: week_number) do |week|
      # Set begin and end dates based on week number
      year = week_number / 100
      week_of_year = week_number % 100
      
      # Calculate the start of the week (Monday)
      jan_first = Date.new(year, 1, 1)
      days_to_first_monday = (8 - jan_first.wday) % 7
      first_monday = jan_first + days_to_first_monday
      
      week.begin_date = first_monday + ((week_of_year - 1) * 7).days
      week.end_date = week.begin_date + 6.days
    end
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

  def approved_prs
    open_prs.joins(:reviews).merge(Review.approved).distinct
  end

  def started_prs
    repository.pull_requests.where(gh_created_at: begin_date.in_time_zone.beginning_of_day..end_date.in_time_zone.end_of_day)
  end

  def cancelled_prs
    closed_prs.where(gh_merged_at: nil)
  end

  # excluding weekends
  def avg_hours_to_first_review
    valid_prs = first_review_prs.select do |pr|
      pr.time_to_first_review.present?
    end
    total_hours = valid_prs.sum do |pr|
      pr.time_to_first_review / 1.hour
    end

    count = valid_prs.length
    count > 0 ? (total_hours.to_f / count).round(2) : nil
  end

  def raw_avg_hours_to_first_review
    valid_prs = first_review_prs.select do |pr|
      pr.raw_time_to_first_review.present?
    end

    total_hours = valid_prs.sum do |pr|
      pr.raw_time_to_first_review # / 1.hour
    end

    count = valid_prs.length
    count > 0 ? (total_hours / count).round(2) : nil
  end

    # Average hours to merge excluding weekends
  def avg_hours_to_merge
    valid_prs = merged_prs.where.not(ready_for_review_at: nil).select do |pr|
      pr.weekday_hours_to_merge.present?
    end

    total_hours = valid_prs.sum do |pr|
      pr.weekday_hours_to_merge / 1.hour
    end

    count = valid_prs.length
    count > 0 ? (total_hours / count).round(2) : nil
  end

  # Original average hours to merge calculation that includes weekends
  def raw_avg_hours_to_merge
    merged_prs.where.not(ready_for_review_at: nil)
              .average("EXTRACT(EPOCH FROM (gh_merged_at - ready_for_review_at)) / 3600")
              &.round(2)
  end
end
