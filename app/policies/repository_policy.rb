class RepositoryPolicy < ApplicationPolicy
  def show?
    true
  end

  # The repository list is Repository.all, not a policy scope. A rule that
  # hides a repository from some users must also be applied there before it
  # takes full effect.
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

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
