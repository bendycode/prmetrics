class ContributorsController < ApplicationController
  def index
    @contributors = Contributor.order(:username, :id).page(page_param).per(10)
  end

  def show
    @contributor = Contributor.find(params[:id])
    @pull_request_users = @contributor.pull_request_users.includes(:pull_request)
                                      .order(id: :desc).page(page_param).per(10)
  end
end
