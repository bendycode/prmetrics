class UsersController < ApplicationController
  before_action :set_user, only: [:destroy]

  def index
    authorize User
    @users = User.all.order(:email)
  end

  def new
    authorize User
    @user = User.new
  end

  def create
    authorize User
    role = params[:user][:role] == '1' ? :admin : :regular_user
    @user = User.invite!(user_params.merge(role: role), current_user)

    if @user.errors.empty?
      redirect_to users_path, notice: "Invitation sent to #{@user.email}"
    else
      render :new
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

  def user_params
    params.require(:user).permit(:email)
  end

  def can_delete_user?
    # If this is a pending invitation, always allow deletion
    return true if @user.invitation_accepted_at.nil?

    # Use User model's last_admin? method
    return true unless @user.admin?
    !User.last_admin?(@user)
  end
end