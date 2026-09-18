class PullRequestPolicy < ApplicationPolicy
  def show?
    Scope.new(user, PullRequest).resolve.exists?(record.id)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if user&.admin?

      scope.where(repository: RepositoryPolicy::Scope.new(user, Repository).resolve)
    end
  end
end
