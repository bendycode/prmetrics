class UsersController < ApplicationController
  before_action :set_user, only: [:destroy]

  def index
    authorize User
    @users = policy_scope(User).order(:email)
  end

  def new
    authorize User
    @user = User.new
    set_repositories
  end

  # devise_invitable resends an invitation whose email is still pending. The
  # block runs before the user is saved and the email is sent, and only for a
  # brand-new user, so a resend changes nothing else about that person.
  def create
    authorize User
    @user = User.invite!({ email: invite_params[:email] }, current_user) do |user|
      next unless user.new_record?

      user.role = invite_params[:role]
      user.granted_repository_ids = invite_params[:granted_repository_ids] if user.regular_user?
    end

    if @user.errors.any?
      set_repositories
      render :new, status: :unprocessable_content
    elsif @user.previously_new_record?
      redirect_to users_path, notice: "Invitation sent to #{@user.email}."
    else
      redirect_to users_path, notice: "Invitation resent to #{@user.email}. Role and repository access are unchanged."
    end
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

  def set_repositories
    @repositories = policy_scope(Repository).order(:name)
  end

  def invite_params
    @invite_params ||= begin
      permitted = params.require(:user).permit(:email, :admin_role_admin, granted_repository_ids: [])
      permitted[:role] = permitted.delete(:admin_role_admin) == 'admin' ? :admin : :regular_user
      permitted[:granted_repository_ids] = Repository.where(id: permitted[:granted_repository_ids]).ids
      permitted
    end
  end

  def can_delete_user?
    # If this is a pending invitation, always allow deletion
    return true if @user.invitation_accepted_at.nil?

    # Use User model's last_admin? method
    return true unless @user.admin?

    !User.last_admin?(@user)
  end
end
