class DashboardController < ApplicationController
  def index
    @repositories = Repository.includes(:weeks).order(:name)
    @total_repositories = @repositories.count
    
    # Get latest week data for overview
    @latest_weeks = Week.includes(:repository)
                       .order(begin_date: :desc)
                       .limit(10)
    
    # Calculate overall statistics
    @total_prs = PullRequest.count
    @total_reviews = Review.count
    @avg_time_to_review = calculate_avg_time_to_review
    @avg_time_to_merge = calculate_avg_time_to_merge
  end

  private

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