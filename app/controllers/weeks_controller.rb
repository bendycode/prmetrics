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
             @week.started_prs.includes(:author, :reviews)
           when 'open'
             @week.open_prs.includes(:author, :reviews)
           when 'first_reviewed'
             @week.first_review_prs.includes(:author, :reviews)
           when 'merged'
             @week.merged_prs.includes(:author, :reviews)
           when 'cancelled'
             @week.cancelled_prs.includes(:author, :reviews)
           when 'draft'
             @week.draft_prs.includes(:author, :reviews)
           else
             []
           end
    render partial: 'pr_list', locals: { prs: @prs, category: @category }
  end
end
