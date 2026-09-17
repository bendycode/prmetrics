class DashboardController < ApplicationController
  def index
    authorize :dashboard
    repositories = policy_scope(Repository)
    @repositories = repositories.includes(:weeks).order(:name)
    @total_repositories = @repositories.count
    # Only a single numeric id of a repository the user may see selects it;
    # anything else (blank, an array, a deleted or ungranted id) renders the
    # unfiltered dashboard. Every filter below derives from the found record,
    # never from the raw param.
    repository_id = params[:repository_id].to_s[/\A\d+\z/]
    @selected_repository = repositories.find_by(id: repository_id) if repository_id
    @selected_repository_id = @selected_repository&.id

    weeks_scope = policy_scope(Week)
    weeks_scope = weeks_scope.where(repository: @selected_repository) if @selected_repository

    @latest_weeks = weeks_scope.includes(:repository).order(begin_date: :desc).limit(10)

    # A selected repository charts its own last 12 weeks; otherwise each week
    # sums across the repositories the user can see.
    chart_scope = weeks_scope.includes(repository: { pull_requests: :reviews })
    @chart_weeks = if @selected_repository
                     chart_scope.order(begin_date: :asc).last(12)
                   else
                     aggregate_weeks_data(
                       chart_scope.order(begin_date: :desc).group_by(&:begin_date).values.first(12).reverse
                     )
                   end

    @repository_stats = prepare_repository_stats

    pull_requests_scope = policy_scope(PullRequest)
    pull_requests_scope = pull_requests_scope.where(repository: @selected_repository) if @selected_repository

    @total_prs = pull_requests_scope.count
    @avg_time_to_review = calculate_avg_time_to_review(pull_requests_scope)
    @avg_time_to_merge = calculate_avg_time_to_merge(pull_requests_scope)
  end

  private

  def prepare_repository_stats
    @repositories.map do |repo|
      recent_weeks = repo.weeks.sort_by(&:begin_date).last(4)
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
      # Sum this week across the repositories the user can see
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

  def calculate_avg_time_to_review(pull_requests)
    review_windows = pull_requests.where.not(ready_for_review_at: nil)
                                  .joins(:reviews)
                                  .group('pull_requests.id')
                                  .pluck(:ready_for_review_at, Arel.sql('MIN(reviews.submitted_at)'))
    average_weekday_hours(review_windows)
  end

  def calculate_avg_time_to_merge(pull_requests)
    merge_windows = pull_requests.where.not(gh_merged_at: nil)
                                 .where.not(ready_for_review_at: nil)
                                 .pluck(:ready_for_review_at, :gh_merged_at)
    average_weekday_hours(merge_windows)
  end

  # Weekday hours depend on the day each time falls on, so both ends move into
  # the configured time zone first: a plucked SQL aggregate such as MIN comes
  # back as a UTC Time rather than a zoned attribute.
  def average_weekday_hours(windows)
    return 0 if windows.empty?

    total_hours = windows.sum do |from, to|
      WeekdayHours.weekday_hours_between(from&.in_time_zone, to&.in_time_zone)
    end
    (total_hours / windows.size).round(1)
  end
end
