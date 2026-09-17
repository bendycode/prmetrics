class ApplicationController < ActionController::Base
  include Pundit::Authorization

  before_action :authenticate_user!
  after_action :verify_authorized, unless: :devise_controller?
  # An index action that never calls policy_scope raises, so a new list is not
  # written as Model.all by accident; the ungranted-repository leak spec checks
  # what each page actually renders. The lambda, rather than only: :index,
  # keeps controllers with no index action from raising on a missing callback.
  after_action :verify_policy_scoped, if: -> { action_name == 'index' }, unless: :devise_controller?
  layout 'admin'

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  helper_method :page_param

  private

  # Kaminari calls to_i on whatever it is given and multiplies the result into
  # an OFFSET with no cap, so an array, a hash, or an oversized number each
  # raise. Only a one-to-six-digit value passes; that is far past any real
  # page count and keeps the OFFSET small. Zero and every rejected value come
  # back as nil, which Kaminari reads as the first page and url_for drops
  # from generated links.
  def page_param
    params[:page].to_s[/\A\d{1,6}\z/]&.to_i&.nonzero?
  end

  def user_not_authorized
    flash[:alert] = 'You are not authorized'
    redirect_to root_path
  end
end
