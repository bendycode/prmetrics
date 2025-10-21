class AccountsController < ApplicationController
  before_action :set_user
  before_action :set_minimum_password_length, only: [:edit]

  def edit
  end

  def update
    if update_user
      redirect_to edit_account_path, notice: 'Account was successfully updated.'
    else
      render :edit
    end
  end

  private

  def set_user
    @user = current_user
  end

  def set_minimum_password_length
    @minimum_password_length = Devise.password_length.min
  end

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation, :current_password)
  end

  def update_user
    if user_params[:password].present?
      @user.update_with_password(user_params)
    else
      params[:user].delete(:current_password)
      @user.update_without_password(user_params.except(:password, :password_confirmation, :current_password))
    end
  end
end
