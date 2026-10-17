class TrackerPolicy < ApplicationPolicy
  def show?
    Scope.new(user, Tracker).resolve.exists?(record.id)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user

      scope.visible_to(user)
    end
  end
end
