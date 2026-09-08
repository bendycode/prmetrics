class PullRequestPolicy < ApplicationPolicy
  def show?
    Pundit.policy!(user, record.repository).show?
  end
end
