require 'rails_helper'

RSpec.describe UserPolicy, type: :policy do
  let(:admin_user) { build(:user, :admin) }
  let(:regular_user) { build(:user) }
  let(:target_user) { build(:user) }

  describe '#show?' do
    it 'allows admin users to view other users' do
      policy = UserPolicy.new(admin_user, target_user)
      expect(policy.show?).to be true
    end

    it 'allows regular users to view other users' do
      policy = UserPolicy.new(regular_user, target_user)
      expect(policy.show?).to be true
    end

    it 'allows users to view themselves' do
      policy = UserPolicy.new(regular_user, regular_user)
      expect(policy.show?).to be true
    end
  end

  describe '#index?' do
    it 'allows admin users to view user list' do
      policy = UserPolicy.new(admin_user, User)
      expect(policy.index?).to be true
    end

    it 'denies regular users from viewing user list' do
      policy = UserPolicy.new(regular_user, User)
      expect(policy.index?).to be false
    end
  end

  describe '#create?' do
    it 'allows admin users to create new users' do
      policy = UserPolicy.new(admin_user, User)
      expect(policy.create?).to be true
    end

    it 'denies regular users from creating new users' do
      policy = UserPolicy.new(regular_user, User)
      expect(policy.create?).to be false
    end
  end

  describe '#new?' do
    it 'allows admin users to access new user form' do
      policy = UserPolicy.new(admin_user, User)
      expect(policy.new?).to be true
    end

    it 'denies regular users from accessing new user form' do
      policy = UserPolicy.new(regular_user, User)
      expect(policy.new?).to be false
    end
  end

  describe '#update?' do
    it 'allows admin users to update other users' do
      policy = UserPolicy.new(admin_user, target_user)
      expect(policy.update?).to be true
    end

    it 'allows users to update themselves' do
      policy = UserPolicy.new(regular_user, regular_user)
      expect(policy.update?).to be true
    end

    it 'denies regular users from updating other users' do
      policy = UserPolicy.new(regular_user, target_user)
      expect(policy.update?).to be false
    end
  end

  describe '#edit?' do
    it 'allows admin users to edit other users' do
      policy = UserPolicy.new(admin_user, target_user)
      expect(policy.edit?).to be true
    end

    it 'allows users to edit themselves' do
      policy = UserPolicy.new(regular_user, regular_user)
      expect(policy.edit?).to be true
    end

    it 'denies regular users from editing other users' do
      policy = UserPolicy.new(regular_user, target_user)
      expect(policy.edit?).to be false
    end
  end

  describe '#destroy?' do
    it 'allows admin users to destroy other users' do
      policy = UserPolicy.new(admin_user, target_user)
      expect(policy.destroy?).to be true
    end

    it 'denies regular users from destroying other users' do
      policy = UserPolicy.new(regular_user, target_user)
      expect(policy.destroy?).to be false
    end

    it 'denies users from destroying themselves' do
      policy = UserPolicy.new(regular_user, regular_user)
      expect(policy.destroy?).to be false
    end
  end

  describe '#admin?' do
    it 'allows admin users' do
      policy = UserPolicy.new(admin_user, nil)
      expect(policy.admin?).to be true
    end

    it 'denies regular users' do
      policy = UserPolicy.new(regular_user, nil)
      expect(policy.admin?).to be false
    end
  end

  describe '#invite?' do
    it 'allows admin users to invite new users' do
      policy = UserPolicy.new(admin_user, User)
      expect(policy.invite?).to be true
    end

    it 'denies regular users from inviting new users' do
      policy = UserPolicy.new(regular_user, User)
      expect(policy.invite?).to be false
    end
  end

  describe '#change_role?' do
    it 'allows admin users to change user roles' do
      policy = UserPolicy.new(admin_user, target_user)
      expect(policy.change_role?).to be true
    end

    it 'denies regular users from changing user roles' do
      policy = UserPolicy.new(regular_user, target_user)
      expect(policy.change_role?).to be false
    end

    it 'denies users from changing their own role' do
      policy = UserPolicy.new(admin_user, admin_user)
      expect(policy.change_role?).to be false
    end
  end

  describe 'admin protection logic' do
    let(:other_admin) { build(:user, :admin) }

    describe '#destroy?' do
      context 'when target is an admin' do
        it 'allows admin to destroy other admins if not the last admin' do
          policy = UserPolicy.new(admin_user, other_admin)
          expect(policy.destroy?).to be true
        end

        it 'denies admin from destroying themselves' do
          policy = UserPolicy.new(admin_user, admin_user)
          expect(policy.destroy?).to be false
        end
      end
    end
  end
end