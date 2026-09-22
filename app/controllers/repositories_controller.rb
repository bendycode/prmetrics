class RepositoriesController < ApplicationController
  before_action :set_repository, only: %i[show sync destroy]

  def index
    authorize Repository
    @repositories = policy_scope(Repository).order(:name)
  end

  def show
    authorize @repository
    @weeks = @repository.weeks.ordered.page(page_param).per(25)
  end

  def new
    authorize Repository
    @repository = Repository.new
  end

  def create
    authorize Repository
    @repository = Repository.new(repository_params)

    if @repository.save
      UnifiedSyncJob.perform_later(@repository, fetch_all: true)
      redirect_to @repository, notice: 'Repository added successfully. Initial sync has been queued.'
    else
      render :new, status: :unprocessable_content
    end
  end

  def sync
    authorize @repository
    fetch_all = params[:fetch_all] == 'true'

    UnifiedSyncJob.perform_later(@repository, fetch_all: fetch_all)

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
    @repository = policy_scope(Repository).find(params[:id])
  end

  def repository_params
    params.require(:repository).permit(:name, :url)
  end
end
