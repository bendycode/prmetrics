class WeekStatsService
  def self.update_all_weeks
    Week.find_each do |week|
      new(week).update_stats
    end
  end

  def self.generate_weeks_for_repository(repository)
    oldest_date = [
      repository.pull_requests.minimum(:gh_created_at),
      repository.pull_requests.minimum(:ready_for_review_at),
      repository.pull_requests.minimum(:gh_merged_at),
      repository.pull_requests.minimum(:gh_closed_at)
    ].compact.min

    return unless oldest_date

    # Convert to Central Time for consistent week calculation
    ct_oldest = oldest_date.in_time_zone("America/Chicago")
    start_date = ct_oldest.beginning_of_week
    end_date = Time.current.in_time_zone("America/Chicago").end_of_week

    (start_date.to_date..end_date.to_date).step(7) do |date|
      # Use Central Time for week boundaries
      ct_date = date.in_time_zone("America/Chicago")
      week_begin = ct_date.beginning_of_week.to_date
      week_end = ct_date.end_of_week.to_date
      week_number = ct_date.strftime('%Y%W').to_i

      repository.weeks.find_or_create_by!(week_number: week_number) do |week|
        week.begin_date = week_begin
        week.end_date = week_end
      end
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
      num_prs_late: calculate_num_prs_late,
      num_prs_stale: calculate_num_prs_stale,
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
    # Use week association for consistency
    @repository.pull_requests.where(draft: false)
      .where(ready_for_review_week_id: @week.id)
      .count
  end

  def calculate_prs_merged
    # Use week association directly for consistency with how PRs are assigned to weeks
    @repository.pull_requests.where(merged_week_id: @week.id).count
  end

  def calculate_num_prs_initially_reviewed
    # Count PRs that had their first review in this week
    @repository.pull_requests
      .where(first_review_week_id: @week.id)
      .count
  end

  def calculate_prs_cancelled
    # Use week association for consistency
    @repository.pull_requests.where(state: 'closed', gh_merged_at: nil)
      .where(closed_week_id: @week.id)
      .count
  end

  def calculate_avg_hrs_to_first_review
    # Calculate average hours for PRs that had their first review in this week
    prs_with_first_review = @repository.pull_requests
      .where(first_review_week_id: @week.id)
      .where.not(ready_for_review_at: nil)
      .includes(:reviews)

    total_hours = prs_with_first_review.sum do |pr|
      first_review = pr.valid_first_review
      next 0 unless first_review

      time_to_review = ((first_review.submitted_at - pr.ready_for_review_at) / 1.hour).round(2)
      raise "negative time to review for pr #{pr.id}: #{time_to_review} hours" if time_to_review.negative?

      time_to_review
    end

    count = prs_with_first_review.count
    count > 0 ? (total_hours / count).round(2) : nil
  end

  def calculate_avg_hrs_to_merge
    # Use week association for consistency
    merged_prs = @repository.pull_requests
      .where(merged_week_id: @week.id)
      .where.not(ready_for_review_at: nil)

    total_hours = merged_prs.sum do |pr|
      ((pr.gh_merged_at - pr.ready_for_review_at) / 1.hour).round(2)
    end

    count = merged_prs.count

    count > 0 ? (total_hours / count).round(2) : nil
  end

  def calculate_num_prs_late
    # PRs approved 8-27 days ago (relative to week end_date)
    # Must be open, not merged, and not draft
    end_timestamp = @week.end_date.in_time_zone.end_of_day

    @repository.pull_requests
      .approved
      .open_at(end_timestamp)
      .unmerged_at(end_timestamp)
      .where(draft: false)
      .select { |pr| (8..27).cover?(pr.days_since_first_approval(@week.end_date)) }
      .count
  end

  def calculate_num_prs_stale
    # PRs approved 28+ days ago (relative to week end_date)
    # Must be open, not merged, and not draft
    end_timestamp = @week.end_date.in_time_zone.end_of_day

    @repository.pull_requests
      .approved
      .open_at(end_timestamp)
      .unmerged_at(end_timestamp)
      .where(draft: false)
      .select { |pr| pr.days_since_first_approval(@week.end_date) >= 28 }
      .count
  end
end
