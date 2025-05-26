class RepositoriesController < ApplicationController
  def index
    @repositories = Repository.all
  end

  def show
    @repository = Repository.find(params[:id])
    @pull_requests = @repository.pull_requests.page(params[:page]).per(10)
  end

  def new
    @repository = Repository.new
  end

  def create
    @repository = Repository.new(repository_params)
    
    if @repository.save
      # Queue initial sync job
      SyncRepositoryJob.perform_later(@repository.name, fetch_all: true)
      redirect_to @repository, notice: "Repository added successfully. Initial sync has been queued."
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def sync
    @repository = Repository.find(params[:id])
    fetch_all = params[:fetch_all] == 'true'
    
    SyncRepositoryJob.perform_later(@repository.name, fetch_all: fetch_all)
    
    redirect_to @repository, notice: "Sync job queued for #{@repository.name}"
  end

  private

  def repository_params
    params.require(:repository).permit(:name, :url)
  end
end
