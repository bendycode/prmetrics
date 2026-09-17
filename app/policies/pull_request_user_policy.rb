class PullRequestUserPolicy < ApplicationPolicy
  def show?
    Scope.new(user, PullRequestUser).resolve.exists?(record.id)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if user&.admin?

      scope.where(pull_request: PullRequestPolicy::Scope.new(user, PullRequest).resolve)
    end
  end
end
