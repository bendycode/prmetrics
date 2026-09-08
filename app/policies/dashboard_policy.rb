class DashboardPolicy < ApplicationPolicy
  # The not-authorized handler redirects to the dashboard, so a denial here
  # would send the user around in a loop. This policy stays unconditional.
  def index?
    true
  end
end
