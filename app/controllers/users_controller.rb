class UsersController < ApplicationController
  before_action :set_user, only: %i[edit update destroy]

  def index
    authorize User
    @users = policy_scope(User).order(:email)
  end

  def new
    authorize User
    @user = User.new
    @repositories = policy_scope(Repository).order(:name)
  end

  def edit
    authorize @user, :manage_grants?
    @repositories = policy_scope(Repository).order(:name)
  end

  def create
    authorize User
    pending_user = User.invitation_not_accepted.find_by(email: user_params[:email].to_s.strip.downcase)
    return resend_invitation(pending_user) if pending_user

    @user = User.invite!(user_params, current_user)

    if @user.errors.empty?
      @user.update!(granted_repository_ids: grant_params.fetch(:granted_repository_ids, [])) if @user.regular_user?
      redirect_to users_path, notice: "Invitation sent to #{@user.email}"
    else
      @repositories = policy_scope(Repository).order(:name)
      render :new
    end
  end

  def update
    authorize @user, :manage_grants?
    @user.update!(granted_repository_ids: grant_params.fetch(:granted_repository_ids, []))
    redirect_to users_path, notice: "Repository access updated for #{@user.email}"
  end

  def destroy
    authorize @user
    if can_delete_user?
      @user.destroy
      redirect_to users_path, notice: 'User was successfully removed.'
    else
      redirect_to users_path, alert: 'Cannot delete the last admin.'
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    permitted = params.require(:user).permit(:email, :admin_role_admin)
    permitted[:role] = permitted.delete(:admin_role_admin) == 'admin' ? :admin : :regular_user
    permitted
  end

  # Inviting an email whose invitation is still pending resends it and nothing
  # more: the form's role and repositories would otherwise overwrite what the
  # admin chose when first inviting that person.
  def resend_invitation(user)
    user.invite!(current_user)
    redirect_to users_path, notice: "Invitation resent to #{user.email}; role and repository access unchanged"
  end

  def grant_params
    params.fetch(:user, {}).permit(granted_repository_ids: [])
  end

  def can_delete_user?
    # If this is a pending invitation, always allow deletion
    return true if @user.invitation_accepted_at.nil?

    # Use User model's last_admin? method
    return true unless @user.admin?

    !User.last_admin?(@user)
  end
end
