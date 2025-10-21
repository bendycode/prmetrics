class ApplicationController < ActionController::Base
  include Pundit::Authorization

  before_action :authenticate_user!
  layout 'admin'

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized
    flash[:alert] = 'You are not authorized'
    redirect_to root_path
  end
end
