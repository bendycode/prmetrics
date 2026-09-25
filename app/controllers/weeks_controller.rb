class WeeksController < ApplicationController
  # The pull request lists a week page can open, by category. Only these exact
  # strings return a list, so an Array or a Hash cannot reach the partial,
  # whose heading calls titleize on whatever it is given.
  PR_LISTS = {
    'started' => ->(week) { week.started_prs.includes(:author) },
    'open' => ->(week) { week.open_prs.includes(:author) },
    'first_reviewed' => ->(week) { week.first_review_prs.includes(:author) },
    'late' => ->(week) { week.late_prs },
    'stale' => ->(week) { week.stale_prs },
    'merged' => ->(week) { week.merged_prs.includes(:author) },
    'cancelled' => ->(week) { week.cancelled_prs.includes(:author) },
    'draft' => ->(week) { week.draft_prs.includes(:author) }
  }.freeze

  before_action :set_week, only: %i[show pr_list]

  def show
    authorize @week
    @previous_week = @week.previous_week
    @next_week = @week.next_week
  end

  def pr_list
    authorize @week, :show?
    category = params[:category]
    list = PR_LISTS[category]
    return head :no_content unless list

    prs = list.call(@week)

    # Only HTML: every other action refuses a format suffix with 406, and an explicit
    # render would answer one with the partial's HTML under a lying content type.
    respond_to do |format|
      format.html { render partial: 'pr_list', locals: { prs: prs, category: category } }
    end
  end

  private

  def set_week
    @repository = policy_scope(Repository).find(params[:repository_id])
    @week = @repository.weeks.find(params[:id])
  end
end
