# Which repositories a regular user may see. Only an admin changes this, and
# only for a regular user; admins see every repository without grants.
class RepositoryAccessesController < ApplicationController
  before_action :set_user

  def edit
    @repositories = policy_scope(Repository).order(:name)
  end

  def update
    @user.update!(granted_repository_ids: Repository.where(id: access_params[:granted_repository_ids]).ids)
    redirect_to users_path, notice: "Repository access updated for #{@user.email}."
  end

  private

  def set_user
    @user = User.find(params[:user_id])
    authorize @user, :manage_grants?
  end

  def access_params
    params.require(:user).permit(granted_repository_ids: [])
  end
end
