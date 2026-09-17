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
  # granted; the week, pull request, review, participant, and contributor
  # scopes all narrow through this one.
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user
      return scope.all if user.admin?

      scope.where(id: user.repository_grants.select(:repository_id))
    end
  end
end
