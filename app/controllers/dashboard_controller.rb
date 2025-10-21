class DashboardController < ApplicationController
  def index
    @repositories = Repository.includes(:weeks).order(:name)
    @total_repositories = @repositories.count
    @selected_repository_id = params[:repository_id]

    # Filter by repository if selected
    weeks_scope = Week.includes(:repository)
    if @selected_repository_id.present?
      weeks_scope = weeks_scope.where(repository_id: @selected_repository_id)
    end

    # Get latest week data for overview
    @latest_weeks = weeks_scope
                      .order(begin_date: :desc)
                      .limit(10)

    # Get data for charts (last 12 weeks for trends)
    # When filtering by repository, get all weeks; otherwise limit to 12
    if @selected_repository_id.present?
      @chart_weeks = weeks_scope
                        .includes(repository: {pull_requests: :reviews})
                        .order(begin_date: :asc)
                        .last(12)
    else
      # For all repositories, group by week and aggregate
      # Preload associations needed for approved_prs calculation
      @chart_weeks = aggregate_weeks_data(
        Week.includes(repository: {pull_requests: :reviews})
            .order(begin_date: :desc)
            .group_by(&:begin_date)
            .values
            .first(12)
            .reverse
      )
    end

    # Prepare repository comparison data
    @repository_stats = prepare_repository_stats

    # Calculate overall statistics (filtered by repository if selected)
    pull_requests_scope = PullRequest.joins(:repository)
    if @selected_repository_id.present?
      pull_requests_scope = pull_requests_scope.where(repository_id: @selected_repository_id)
    end

    @total_prs = pull_requests_scope.count
    @total_reviews = Review.joins(pull_request: :repository)
    @total_reviews = @total_reviews.where(pull_requests: { repository_id: @selected_repository_id }) if @selected_repository_id.present?
    @total_reviews = @total_reviews.count

    @avg_time_to_review = calculate_avg_time_to_review(@selected_repository_id)
    @avg_time_to_merge = calculate_avg_time_to_merge(@selected_repository_id)
  end

  private

  def prepare_repository_stats
    @repositories.map do |repo|
      recent_weeks = repo.weeks.order(:begin_date).last(4) # Last 4 weeks
      next if recent_weeks.empty?

      # Calculate averages only from weeks that have data
      review_times = recent_weeks.map(&:avg_hrs_to_first_review).compact
      merge_times = recent_weeks.map(&:avg_hrs_to_merge).compact

      {
        name: repo.name,
        total_prs: recent_weeks.sum { |w| w.num_prs_started || 0 },
        avg_review_time: review_times.empty? ? 0 : (review_times.sum / review_times.count).round(1),
        avg_merge_time: merge_times.empty? ? 0 : (merge_times.sum / merge_times.count).round(1),
        merge_rate: calculate_merge_rate(recent_weeks)
      }
    end.compact
  end

  def calculate_merge_rate(weeks)
    total_started = weeks.sum { |w| w.num_prs_started || 0 }
    total_merged = weeks.sum { |w| w.num_prs_merged || 0 }
    return 0 if total_started == 0
    ((total_merged.to_f / total_started) * 100).round(1)
  end

  def aggregate_weeks_data(grouped_weeks)
    grouped_weeks.map do |weeks_for_date|
      # Aggregate data from all repositories for this week
      first_week = weeks_for_date.first
      aggregated_week = Week.new(
        begin_date: first_week.begin_date,
        end_date: first_week.end_date,
        week_number: first_week.week_number,
        num_prs_started: weeks_for_date.sum { |w| w.num_prs_started || 0 },
        num_prs_merged: weeks_for_date.sum { |w| w.num_prs_merged || 0 },
        num_prs_cancelled: weeks_for_date.sum { |w| w.num_prs_cancelled || 0 },
        avg_hrs_to_first_review: calculate_weighted_avg(weeks_for_date, :avg_hrs_to_first_review, :num_prs_started),
        avg_hrs_to_merge: calculate_weighted_avg(weeks_for_date, :avg_hrs_to_merge, :num_prs_merged)
      )

      # Add aggregated late and stale counts as singleton methods
      aggregated_late_count = weeks_for_date.sum(&:num_prs_late)
      aggregated_stale_count = weeks_for_date.sum(&:num_prs_stale)
      aggregated_week.define_singleton_method(:num_prs_late) { aggregated_late_count }
      aggregated_week.define_singleton_method(:num_prs_stale) { aggregated_stale_count }

      aggregated_week
    end
  end

  def calculate_weighted_avg(weeks, attr, weight_attr)
    total_weight = 0
    weighted_sum = 0

    weeks.each do |week|
      value = week.send(attr)
      weight = week.send(weight_attr)

      if value && weight && weight > 0
        weighted_sum += value * weight
        total_weight += weight
      end
    end

    return nil if total_weight == 0
    (weighted_sum / total_weight).round(1)
  end

  def calculate_avg_time_to_review(repository_id = nil)
    prs_with_first_review = PullRequest.joins(:reviews)
                                     .where.not(ready_for_review_at: nil)
                                     .distinct

    if repository_id.present?
      prs_with_first_review = prs_with_first_review.where(repository_id: repository_id)
    end

    return 0 if prs_with_first_review.empty?

    total_hours = prs_with_first_review.sum do |pr|
      first_review = pr.reviews.order(:submitted_at).first
      next 0 unless first_review&.submitted_at && pr.ready_for_review_at

      WeekdayHours.weekday_hours_between(pr.ready_for_review_at, first_review.submitted_at)
    end

    (total_hours / prs_with_first_review.count).round(1)
  end

  def calculate_avg_time_to_merge(repository_id = nil)
    merged_prs = PullRequest.where.not(gh_merged_at: nil, ready_for_review_at: nil)

    if repository_id.present?
      merged_prs = merged_prs.where(repository_id: repository_id)
    end

    return 0 if merged_prs.empty?

    total_hours = merged_prs.sum do |pr|
      WeekdayHours.weekday_hours_between(pr.ready_for_review_at, pr.gh_merged_at)
    end

    (total_hours / merged_prs.count).round(1)
  end
end