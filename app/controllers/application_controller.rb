class ApplicationController < ActionController::Base
  include Pundit::Authorization

  before_action :authenticate_user!
  layout 'admin'

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  helper_method :page_param

  private

  # Kaminari calls to_i on whatever it is given and multiplies the result into
  # an OFFSET with no cap, so an array, a hash, or an oversized number each
  # raise. Only a one-to-six-digit value passes; that is far past any real
  # page count and keeps the OFFSET small. Nil (including zero) means the
  # first page and drops the parameter from generated links.
  def page_param
    params[:page].to_s[/\A\d{1,6}\z/]&.to_i&.nonzero?
  end

  def user_not_authorized
    flash[:alert] = 'You are not authorized'
    redirect_to root_path
  end
end
