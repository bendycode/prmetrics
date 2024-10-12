class UsersController < ApplicationController
  def index
    @users = User.page(params[:page]).per(10)
  end

  def show
    @user = User.find(params[:id])
    @pull_request_users = @user.pull_request_users.page(params[:page]).per(10)
  end
end
