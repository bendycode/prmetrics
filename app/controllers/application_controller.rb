class ApplicationController < ActionController::Base
  include Pundit::Authorization

  before_action :authenticate_admin!
  layout 'admin'

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_back(fallback_location: root_path)
  end
end
