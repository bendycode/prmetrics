require 'rails_helper'

RSpec.describe UserPolicy, type: :policy do
  subject { described_class }

  let(:admin_user) { build(:user, role: :admin) }
  let(:regular_user) { build(:user, role: :regular_user) }
  let(:target_user) { build(:user, role: :regular_user) }

  permissions :show? do
    it 'allows admin users to view other users' do
      expect(subject).to permit(admin_user, target_user)
    end

    it 'allows regular users to view other users' do
      expect(subject).to permit(regular_user, target_user)
    end

    it 'allows users to view themselves' do
      expect(subject).to permit(regular_user, regular_user)
    end
  end

  permissions :index? do
    it 'allows admin users to view user list' do
      expect(subject).to permit(admin_user, User)
    end

    it 'denies regular users from viewing user list' do
      expect(subject).not_to permit(regular_user, User)
    end
  end

  permissions :create? do
    it 'allows admin users to create new users' do
      expect(subject).to permit(admin_user, User)
    end

    it 'denies regular users from creating new users' do
      expect(subject).not_to permit(regular_user, User)
    end
  end

  permissions :new? do
    it 'allows admin users to access new user form' do
      expect(subject).to permit(admin_user, User)
    end

    it 'denies regular users from accessing new user form' do
      expect(subject).not_to permit(regular_user, User)
    end
  end

  permissions :update? do
    it 'allows admin users to update other users' do
      expect(subject).to permit(admin_user, target_user)
    end

    it 'allows users to update themselves' do
      expect(subject).to permit(regular_user, regular_user)
    end

    it 'denies regular users from updating other users' do
      expect(subject).not_to permit(regular_user, target_user)
    end
  end

  permissions :edit? do
    it 'allows admin users to edit other users' do
      expect(subject).to permit(admin_user, target_user)
    end

    it 'allows users to edit themselves' do
      expect(subject).to permit(regular_user, regular_user)
    end

    it 'denies regular users from editing other users' do
      expect(subject).not_to permit(regular_user, target_user)
    end
  end

  permissions :destroy? do
    it 'allows admin users to destroy other users' do
      expect(subject).to permit(admin_user, target_user)
    end

    it 'denies regular users from destroying other users' do
      expect(subject).not_to permit(regular_user, target_user)
    end

    it 'denies users from destroying themselves' do
      expect(subject).not_to permit(regular_user, regular_user)
    end
  end

  permissions :admin? do
    it 'allows admin users' do
      expect(subject).to permit(admin_user, nil)
    end

    it 'denies regular users' do
      expect(subject).not_to permit(regular_user, nil)
    end
  end

  permissions :invite? do
    it 'allows admin users to invite new users' do
      expect(subject).to permit(admin_user, User)
    end

    it 'denies regular users from inviting new users' do
      expect(subject).not_to permit(regular_user, User)
    end
  end

  permissions :change_role? do
    it 'allows admin users to change user roles' do
      expect(subject).to permit(admin_user, target_user)
    end

    it 'denies regular users from changing user roles' do
      expect(subject).not_to permit(regular_user, target_user)
    end

    it 'denies users from changing their own role' do
      expect(subject).not_to permit(admin_user, admin_user)
    end
  end

  describe 'admin protection logic' do
    let(:other_admin) { build(:user, role: :admin) }

    permissions :destroy? do
      context 'when target is an admin' do
        it 'allows admin to destroy other admins if not the last admin' do
          expect(subject).to permit(admin_user, other_admin)
        end

        it 'denies admin from destroying themselves' do
          expect(subject).not_to permit(admin_user, admin_user)
        end
      end
    end
  end
end