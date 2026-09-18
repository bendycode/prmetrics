class PullRequestPolicy < ApplicationPolicy
  def show?
    Scope.new(user, PullRequest).resolve.exists?(record.id)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(repository: RepositoryPolicy::Scope.new(user, Repository).resolve)
    end
  end
end
