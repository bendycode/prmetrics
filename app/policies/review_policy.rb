class ReviewPolicy < ApplicationPolicy
  def show?
    Pundit.policy!(user, record.pull_request).show?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(pull_request: PullRequestPolicy::Scope.new(user, PullRequest).resolve)
    end
  end
end
