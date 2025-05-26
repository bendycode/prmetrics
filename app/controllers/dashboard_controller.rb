class DashboardController < ApplicationController
  def index
    @repositories = Repository.includes(:weeks).order(:name)
    @total_repositories = @repositories.count
    
    # Get latest week data for overview
    @latest_weeks = Week.includes(:repository)
                       .order(begin_date: :desc)
                       .limit(10)
    
    # Get data for charts (last 12 weeks for trends)
    @chart_weeks = Week.includes(:repository)
                      .order(begin_date: :desc)
                      .limit(12)
                      .reverse
    
    # Prepare repository comparison data
    @repository_stats = prepare_repository_stats
    
    # Calculate overall statistics
    @total_prs = PullRequest.count
    @total_reviews = Review.count
    @avg_time_to_review = calculate_avg_time_to_review
    @avg_time_to_merge = calculate_avg_time_to_merge
  end

  private

  def prepare_repository_stats
    @repositories.map do |repo|
      recent_weeks = repo.weeks.order(:begin_date).last(4) # Last 4 weeks
      next if recent_weeks.empty?

      {
        name: repo.name,
        total_prs: recent_weeks.sum(&:num_prs_started),
        avg_review_time: recent_weeks.map(&:avg_hrs_to_first_review).compact.sum / [recent_weeks.count, 1].max,
        avg_merge_time: recent_weeks.map(&:avg_hrs_to_merge).compact.sum / [recent_weeks.count, 1].max,
        merge_rate: calculate_merge_rate(recent_weeks)
      }
    end.compact
  end

  def calculate_merge_rate(weeks)
    total_started = weeks.sum(&:num_prs_started)
    total_merged = weeks.sum(&:num_prs_merged)
    return 0 if total_started == 0
    ((total_merged.to_f / total_started) * 100).round(1)
  end

  def calculate_avg_time_to_review
    prs_with_first_review = PullRequest.joins(:reviews)
                                     .where.not(ready_for_review_at: nil)
                                     .distinct
    return 0 if prs_with_first_review.empty?

    total_hours = prs_with_first_review.sum do |pr|
      first_review = pr.reviews.order(:submitted_at).first
      next 0 unless first_review&.submitted_at && pr.ready_for_review_at
      
      WeekdayHours.weekday_hours_between(pr.ready_for_review_at, first_review.submitted_at)
    end

    (total_hours / prs_with_first_review.count).round(1)
  end

  def calculate_avg_time_to_merge
    merged_prs = PullRequest.where.not(gh_merged_at: nil, ready_for_review_at: nil)
    return 0 if merged_prs.empty?

    total_hours = merged_prs.sum do |pr|
      WeekdayHours.weekday_hours_between(pr.ready_for_review_at, pr.gh_merged_at)
    end

    (total_hours / merged_prs.count).round(1)
  end
end