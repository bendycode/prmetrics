class ContributorsController < ApplicationController
  def index
    @contributors = Contributor.page(params[:page]).per(10)
  end

  def show
    @contributor = Contributor.find(params[:id])
    @pull_request_users = @contributor.pull_request_users.includes(:pull_request).page(params[:page]).per(10)
  end
end
