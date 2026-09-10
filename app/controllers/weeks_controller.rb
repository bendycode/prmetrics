class WeeksController < ApplicationController
  def show
    @repository = Repository.find(params[:repository_id])
    @week = @repository.weeks.find(params[:id])
    authorize @week
    @previous_week = @week.previous_week
    @next_week = @week.next_week
  end

  def pr_list
    @repository = Repository.find(params[:repository_id])
    @week = @repository.weeks.find(params[:id])
    authorize @week, :show?
    category = params[:category]
    prs = prs_for_category(category)
    return head :no_content if prs.nil?

    render partial: 'pr_list', locals: { prs: prs, category: category }
  end

  private

  # Every branch below matches a string literal, so only one of these exact
  # categories returns non-nil. That is what keeps the raw param out of the
  # partial, whose heading calls titleize on the category: an Array, a Hash,
  # or ActionController::Parameters cannot satisfy String#===, so an
  # unrecognized shape leaves with head :no_content instead. A `when Array`
  # or a regexp branch added here would put the raw param back in front of
  # the view.
  def prs_for_category(category)
    case category
    when 'started' then @week.started_prs.includes(:author, :reviews)
    when 'open' then @week.open_prs.includes(:author, :reviews)
    when 'first_reviewed' then @week.first_review_prs.includes(:author, :reviews)
    when 'late' then @week.late_prs
    when 'stale' then @week.stale_prs
    when 'merged' then @week.merged_prs.includes(:author, :reviews)
    when 'cancelled' then @week.cancelled_prs.includes(:author, :reviews)
    when 'draft' then @week.draft_prs.includes(:author, :reviews)
    end
  end
end
