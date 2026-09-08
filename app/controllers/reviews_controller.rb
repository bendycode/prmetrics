class ReviewsController < ApplicationController
  def index
    @pull_request = PullRequest.find(params[:pull_request_id])
    authorize @pull_request, :show?
    @reviews = @pull_request.reviews.order(submitted_at: :desc, id: :desc).page(page_param).per(10)
  end

  def show
    @review = Review.find(params[:id])
    authorize @review
  end
end
