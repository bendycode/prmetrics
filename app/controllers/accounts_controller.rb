class AccountsController < ApplicationController
  before_action :set_admin
  before_action :set_minimum_password_length, only: [:edit]

  def edit
  end

  def update
    if update_admin
      redirect_to edit_account_path, notice: 'Account was successfully updated.'
    else
      render :edit
    end
  end

  private

  def set_admin
    @admin = current_admin
  end

  def set_minimum_password_length
    @minimum_password_length = Devise.password_length.min
  end

  def admin_params
    params.require(:admin).permit(:email, :password, :password_confirmation, :current_password)
  end

  def update_admin
    if admin_params[:password].present?
      @admin.update_with_password(admin_params)
    else
      params[:admin].delete(:current_password)
      @admin.update_without_password(admin_params.except(:password, :password_confirmation, :current_password))
    end
  end
end