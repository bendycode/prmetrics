class WeeksController < ApplicationController
  def index
    @repository = Repository.find(params[:repository_id])
    @weeks = @repository.weeks.ordered
  end

  def show
    @repository = Repository.find(params[:repository_id])
    @week = @repository.weeks.find(params[:id])
    @previous_week = @week.previous_week
    @next_week = @week.next_week
  end

  def pr_list
    @repository = Repository.find(params[:repository_id])
    @week = @repository.weeks.find(params[:id])
    @category = params[:category]
    @prs = case @category
           when 'started'
             @week.started_prs
           when 'open'
             @week.open_prs
           when 'first_reviewed'
             @week.first_review_prs
           when 'merged'
             @week.merged_prs
           when 'cancelled'
             @week.cancelled_prs
           when 'draft'
             @week.draft_prs
           else
             []
           end
    render partial: 'pr_list', locals: { prs: @prs, category: @category }
  end
end
