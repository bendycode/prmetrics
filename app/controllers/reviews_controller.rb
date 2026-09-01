class ReviewsController < ApplicationController
  def index
    @pull_request = PullRequest.find(params[:pull_request_id])
    @reviews = @pull_request.reviews.order(submitted_at: :desc, id: :desc).page(params[:page]).per(10)
  end

  def show
    @review = Review.find(params[:id])
  end
end
