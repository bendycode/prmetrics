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
      # Use sync service to determine best sync strategy
      RepositorySyncService.new(@repository, fetch_all: true).perform
      redirect_to @repository, notice: "Repository added successfully. Initial sync has been queued."
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def sync
    @repository = Repository.find(params[:id])
    fetch_all = params[:fetch_all] == 'true'
    
    RepositorySyncService.new(@repository, fetch_all: fetch_all).perform
    
    redirect_to @repository, notice: "Sync job queued for #{@repository.name}"
  end

  private

  def repository_params
    params.require(:repository).permit(:name, :url)
  end
end
