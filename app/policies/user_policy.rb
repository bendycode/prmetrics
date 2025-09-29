class UserPolicy < ApplicationPolicy
  def show?
    true
  end

  def index?
    admin?
  end

  def create?
    admin?
  end

  def update?
    admin? || user_owns_record?
  end

  def destroy?
    admin? && !user_owns_record?
  end

  def invite?
    admin?
  end

  def change_role?
    admin? && !user_owns_record?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user&.admin?
        scope.all
      else
        scope.none
      end
    end
  end
end