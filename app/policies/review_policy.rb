class ReviewPolicy < ApplicationPolicy
  def show?
    Pundit.policy!(user, record.pull_request).show?
  end
end
