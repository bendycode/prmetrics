class PullRequestPolicy < ApplicationPolicy
  def show?
    RepositoryPolicy.new(user, record.repository).show?
  end
end
