class PullRequestsController < ApplicationController
  def index
    @repository = Repository.find(params[:repository_id])
    @pull_requests = @repository.pull_requests.page(params[:page]).per(10)
  end

  def show
    @pull_request = PullRequest.find(params[:id])
    @reviews = @pull_request.reviews.includes(:author).ordered
  end
end
