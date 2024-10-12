class RepositoriesController < ApplicationController
  def index
    @repositories = Repository.all
  end

  def show
    @repository = Repository.find(params[:id])
    @pull_requests = @repository.pull_requests.page(params[:page]).per(10)
  end
end
