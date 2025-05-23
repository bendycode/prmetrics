class RepositoriesController < ApplicationController
  def index
    @repositories = Repository.all
  end

  def show
    @repository = Repository.find(params[:id])
    @pull_requests = @repository.pull_requests.page(params[:page]).per(10)
  end
  
  def sync
    @repository = Repository.find(params[:id])
    fetch_all = params[:fetch_all] == 'true'
    
    SyncRepositoryJob.perform_later(@repository.name, fetch_all: fetch_all)
    
    redirect_to @repository, notice: "Sync job queued for #{@repository.name}"
  end
end
