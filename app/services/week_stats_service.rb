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
    ct_oldest = oldest_date.in_time_zone('America/Chicago')
    start_date = ct_oldest.beginning_of_week
    end_date = Time.current.in_time_zone('America/Chicago').end_of_week

    (start_date.to_date..end_date.to_date).step(7) do |date|
      # Use Central Time for week boundaries
      ct_date = date.in_time_zone('America/Chicago')
      week_begin = ct_date.beginning_of_week.to_date
      week_end = ct_date.end_of_week.to_date
      week_number = week_begin.strftime('%Y%W').to_i

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
      num_prs_approved: calculate_prs_approved,
      num_prs_late: calculate_num_prs_late,
      num_prs_stale: calculate_num_prs_stale,
      avg_hrs_to_first_review: calculate_avg_hrs_to_first_review,
      avg_hrs_to_approval: calculate_avg_hrs_to_approval,
      avg_hrs_to_merge: calculate_avg_hrs_to_merge
    )
  end

  private

  def calculate_open_prs
    end_timestamp = @week.end_date.in_time_zone.end_of_day

    @repository.development_pull_requests
               .where(state: 'open', draft: false)
               .where('gh_created_at <= ?', end_timestamp)
               .where('(gh_closed_at > ? OR gh_closed_at IS NULL)', end_timestamp)
               .where('(ready_for_review_at <= ? OR ready_for_review_at IS NULL)', end_timestamp)
               .count
  end

  def calculate_prs_started
    # Use week association for consistency
    @repository.development_pull_requests.where(draft: false)
               .where(ready_for_review_week_id: @week.id)
               .count
  end

  def calculate_prs_merged
    # Use week association directly for consistency with how PRs are assigned to weeks
    @repository.development_pull_requests.where(merged_week_id: @week.id).count
  end

  def calculate_num_prs_initially_reviewed
    # Count PRs that had their first review in this week
    @repository.development_pull_requests
               .where(first_review_week_id: @week.id)
               .count
  end

  def calculate_prs_cancelled
    # Use week association for consistency
    @repository.development_pull_requests.where(state: 'closed', gh_merged_at: nil)
               .where(closed_week_id: @week.id)
               .count
  end

  def calculate_prs_approved
    @week.first_approval_prs.count
  end

  # Every wait counts weekdays only, which is what the week page and the metric
  # popovers describe.
  def calculate_avg_hrs_to_first_review
    average_wait(@week.first_review_prs, &:valid_first_review_at)
  end

  def calculate_avg_hrs_to_approval
    average_wait(@week.first_approval_prs, &:approved_at)
  end

  def average_wait(pull_requests)
    waits = pull_requests.where.not(ready_for_review_at: nil).filter_map do |pull_request|
      reached_at = yield(pull_request)
      WeekdayHours.weekday_hours_between(pull_request.ready_for_review_at, reached_at) if reached_at
    end

    (waits.sum / waits.size).round(2) if waits.any?
  end

  def calculate_avg_hrs_to_merge
    average_wait(@week.merged_prs, &:gh_merged_at)
  end

  def calculate_num_prs_late
    # PRs approved 8-27 days ago (relative to week end_date)
    # Must be open, not merged, and not draft
    end_timestamp = @week.end_date.in_time_zone.end_of_day

    @repository.development_pull_requests
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

    @repository.development_pull_requests
               .approved
               .open_at(end_timestamp)
               .unmerged_at(end_timestamp)
               .where(draft: false)
               .select { |pr| pr.days_since_first_approval(@week.end_date) >= 28 }
               .count
  end
end
