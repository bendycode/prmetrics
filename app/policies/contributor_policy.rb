class ContributorPolicy < ApplicationPolicy
  # Contributor pages list a person's pull requests across every repository
  # and are not scoped by RepositoryPolicy. A rule that hides a repository
  # from some users must also be applied here before it takes full effect.
  def index?
    true
  end

  def show?
    true
  end
end
