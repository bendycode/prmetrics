class ReviewPolicy < ApplicationPolicy
  def show?
    RepositoryPolicy.new(user, record.pull_request.repository).show?
  end
end
