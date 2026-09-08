class DashboardPolicy < ApplicationPolicy
  # The not-authorized handler redirects to the dashboard, so a denial here
  # would send the user around in a loop. This policy stays unconditional.
  #
  # The unfiltered dashboard lists every repository and every repository's
  # weeks without consulting RepositoryPolicy. A rule that hides a repository
  # from some users must also be applied there before it takes full effect.
  def index?
    true
  end
end
