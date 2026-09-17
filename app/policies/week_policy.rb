class WeekPolicy < ApplicationPolicy
  def show?
    Pundit.policy!(user, record.repository).show?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(repository: RepositoryPolicy::Scope.new(user, Repository).resolve)
    end
  end
end
