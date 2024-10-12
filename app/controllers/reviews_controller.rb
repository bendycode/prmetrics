class ReviewsController < ApplicationController
  def index
    @pull_request = PullRequest.find(params[:pull_request_id])
    @reviews = @pull_request.reviews.page(params[:page]).per(10)
  end

  def show
    @review = Review.find(params[:id])
  end
end
