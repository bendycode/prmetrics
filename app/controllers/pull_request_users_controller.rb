class PullRequestUsersController < ApplicationController
  def index
    @pull_request = policy_scope(PullRequest).find(params[:pull_request_id])
    authorize @pull_request, :show?
    @pull_request_users = @pull_request.pull_request_users.includes(:user)
                                       .order(id: :desc).page(page_param).per(10)
  end

  def show
    @pull_request_user = policy_scope(PullRequestUser).find(params[:id])
    authorize @pull_request_user
  end
end
