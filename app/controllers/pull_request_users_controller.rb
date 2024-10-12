class PullRequestUsersController < ApplicationController
  def index
    @pull_request = PullRequest.find(params[:pull_request_id])
    @pull_request_users = @pull_request.pull_request_users.page(params[:page]).per(10)
  end

  def show
    @pull_request_user = PullRequestUser.find(params[:id])
  end
end
