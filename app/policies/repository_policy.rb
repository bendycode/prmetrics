class RepositoryPolicy < ApplicationPolicy
  def show?
    Scope.new(user, Repository).resolve.exists?(record.id)
  end

  def index?
    true
  end

  def create?
    admin?
  end

  def update?
    admin?
  end

  def destroy?
    admin?
  end

  def sync?
    admin?
  end

  # Every record a regular user may see belongs to a repository they were
  # granted; for a regular user the week, pull request, review, participant,
  # and contributor scopes all narrow through this one. Each of those returns
  # everything to an admin directly rather than filtering by every repository.
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user

      scope.visible_to(user)
    end
  end
end
