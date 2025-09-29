class RepositoriesController < ApplicationController
  before_action :set_repository, only: [:show, :sync, :destroy]

  def index
    authorize Repository
    @repositories = Repository.all
  end

  def show
    authorize @repository
    @pull_requests = @repository.pull_requests.page(params[:page]).per(10)
  end

  def new
    authorize Repository
    @repository = Repository.new
  end

  def create
    authorize Repository
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
    authorize @repository
    fetch_all = params[:fetch_all] == 'true'

    RepositorySyncService.new(@repository, fetch_all: fetch_all).perform

    redirect_to @repository, notice: "Sync job queued for #{@repository.name}"
  end

  def destroy
    authorize @repository
    repository_name = @repository.name

    @repository.destroy
    redirect_to repositories_path, notice: "Repository '#{repository_name}' and all associated data have been deleted."
  end

  private

  def set_repository
    @repository = Repository.find(params[:id])
  end

  def repository_params
    params.require(:repository).permit(:name, :url)
  end
end
