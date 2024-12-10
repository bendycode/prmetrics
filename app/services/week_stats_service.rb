class WeekStatsService
  def self.update_all_weeks
    Week.find_each do |week|
      new(week).update_stats
    end
  end

  def initialize(week)
    @week = week
    @repository = week.repository
  end

  def update_stats
    @week.update(
      num_open_prs: calculate_open_prs,
      num_prs_started: calculate_prs_started,
      num_prs_merged: calculate_prs_merged,
      num_prs_initially_reviewed: calculate_num_prs_initially_reviewed,
      num_prs_cancelled: calculate_prs_cancelled,
      avg_hrs_to_first_review: calculate_avg_hrs_to_first_review,
      avg_hrs_to_merge: calculate_avg_hrs_to_merge
    )
  end

  private

  def calculate_open_prs
    end_timestamp = @week.end_date.in_time_zone.end_of_day

    @repository.pull_requests
      .where(state: 'open', draft: false)
      .where('gh_created_at <= ?', end_timestamp)
      .where('(gh_closed_at > ? OR gh_closed_at IS NULL)', end_timestamp)
      .where('(ready_for_review_at <= ? OR ready_for_review_at IS NULL)', end_timestamp)
      .count
  end

  def calculate_prs_started
    start_timestamp = @week.begin_date.in_time_zone.beginning_of_day
    end_timestamp = @week.end_date.in_time_zone.end_of_day

    @repository.pull_requests.where(draft: false)
      .where(ready_for_review_at: start_timestamp..end_timestamp)
      .count
  end

  def calculate_prs_merged
    start_timestamp = @week.begin_date.in_time_zone.beginning_of_day
    end_timestamp = @week.end_date.in_time_zone.end_of_day

    @repository.pull_requests.where(gh_merged_at: start_timestamp..end_timestamp)
               .count
  end

  def calculate_num_prs_initially_reviewed
    start_timestamp = @week.begin_date.in_time_zone.beginning_of_day
    end_timestamp = @week.end_date.in_time_zone.end_of_day

    @repository.pull_requests
      .joins(:reviews)
      .where(reviews: { submitted_at: start_timestamp..end_timestamp })
      .where('reviews.submitted_at > pull_requests.ready_for_review_at')
      .group('pull_requests.id')
      .having('MIN(reviews.submitted_at) BETWEEN ? AND ?', start_timestamp, end_timestamp)
      .count.length
  end

  def calculate_prs_cancelled
    start_timestamp = @week.begin_date.in_time_zone.beginning_of_day
    end_timestamp = @week.end_date.in_time_zone.end_of_day

    @repository.pull_requests.where(state: 'closed', gh_merged_at: nil)
      .where(gh_closed_at: start_timestamp..end_timestamp)
      .count
  end

  def calculate_avg_hrs_to_first_review
    start_timestamp = @week.begin_date.in_time_zone.beginning_of_day
    end_timestamp = @week.end_date.in_time_zone.end_of_day

    prs_with_first_review = @repository.pull_requests
      .joins(:reviews)
      .where(reviews: { submitted_at: start_timestamp..end_timestamp })
      .where.not(pull_requests: { ready_for_review_at: nil })
      .where('reviews.submitted_at > pull_requests.ready_for_review_at')
      .group('pull_requests.id, pull_requests.ready_for_review_at')
      .having('MIN(reviews.submitted_at) BETWEEN ? AND ?', start_timestamp, end_timestamp)
      .select('pull_requests.id, pull_requests.ready_for_review_at, MIN(reviews.submitted_at) AS first_review_at')

    total_hours = prs_with_first_review.sum do |pr|
      time_to_review = ((pr.first_review_at - pr.ready_for_review_at) / 1.hour).round(2)
      raise "negative time to review for pr #{pr.id}: #{time_to_review} hours" if time_to_review.negative?
      time_to_review
    end

    count = prs_with_first_review.length
    count > 0 ? (total_hours / count).round(2) : nil
  end

  def calculate_avg_hrs_to_merge
    start_timestamp = @week.begin_date.in_time_zone.beginning_of_day
    end_timestamp = @week.end_date.in_time_zone.end_of_day

    merged_prs = @repository.pull_requests
      .where(gh_merged_at: start_timestamp..end_timestamp)
      .where.not(ready_for_review_at: nil)

    total_hours = merged_prs.sum do |pr|
      ((pr.gh_merged_at - pr.ready_for_review_at) / 1.hour).round(2)
    end

    count = merged_prs.count

    count > 0 ? (total_hours / count).round(2) : nil
  end
end
