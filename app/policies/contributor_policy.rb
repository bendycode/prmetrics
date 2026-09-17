class ContributorPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    Scope.new(user, Contributor).resolve.exists?(record.id)
  end

  # A regular user sees a contributor only through activity in a granted
  # repository: an authored pull request, a review, or participation.
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if user&.admin?

      pull_requests = PullRequestPolicy::Scope.new(user, PullRequest).resolve

      scope.where(id: pull_requests.select(:author_id))
           .or(scope.where(id: Review.where(pull_request: pull_requests).select(:author_id)))
           .or(scope.where(id: PullRequestUser.where(pull_request: pull_requests).select(:user_id)))
    end
  end
end
