class WeeksController < ApplicationController
  before_action :set_week, only: %i[show pr_list]

  def show
    authorize @week
    @previous_week = @week.previous_week
    @next_week = @week.next_week
  end

  def pr_list
    authorize @week, :show?
    category = params[:category]
    prs = prs_for_category(category)
    return head :no_content if prs.nil?

    render partial: 'pr_list', formats: [:html], locals: { prs: prs, category: category }
  end

  private

  def set_week
    @repository = Repository.find(params[:repository_id])
    @week = @repository.weeks.find(params[:id])
  end

  # Only these exact strings return a category, so an Array or a Hash cannot reach the
  # partial, whose heading calls titleize on whatever it is given.
  def prs_for_category(category)
    case category
    when 'started' then @week.started_prs.includes(:author)
    when 'open' then @week.open_prs.includes(:author)
    when 'first_reviewed' then @week.first_review_prs.includes(:author)
    when 'late' then @week.late_prs
    when 'stale' then @week.stale_prs
    when 'merged' then @week.merged_prs.includes(:author)
    when 'cancelled' then @week.cancelled_prs.includes(:author)
    when 'draft' then @week.draft_prs.includes(:author)
    end
  end
end
