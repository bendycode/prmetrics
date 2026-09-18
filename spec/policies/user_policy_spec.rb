require 'rails_helper'

RSpec.describe UserPolicy, type: :policy do
  let(:admin_user) { build(:user, :admin) }
  let(:regular_user) { build(:user) }
  let(:target_user) { build(:user) }

  context 'with admin user' do
    let(:user) { admin_user }

    describe '#index?' do
      it 'allows viewing user list' do
        policy = described_class.new(user, User)
        expect(policy.index?).to be true
      end
    end

    describe '#create?' do
      it 'allows creating new users' do
        policy = described_class.new(user, User)
        expect(policy.create?).to be true
      end
    end

    describe '#new?' do
      it 'allows accessing new user form' do
        policy = described_class.new(user, User)
        expect(policy.new?).to be true
      end
    end

    describe '#admin?' do
      it 'allows admin actions' do
        policy = described_class.new(user, nil)
        expect(policy.admin?).to be true
      end
    end
  end

  context 'with regular user' do
    let(:user) { regular_user }

    describe '#index?' do
      it 'denies viewing user list' do
        policy = described_class.new(user, User)
        expect(policy.index?).to be false
      end
    end

    describe '#create?' do
      it 'denies creating new users' do
        policy = described_class.new(user, User)
        expect(policy.create?).to be false
      end
    end

    describe '#new?' do
      it 'denies accessing new user form' do
        policy = described_class.new(user, User)
        expect(policy.new?).to be false
      end
    end

    describe '#admin?' do
      it 'denies admin actions' do
        policy = described_class.new(user, nil)
        expect(policy.admin?).to be false
      end
    end
  end

  describe '#update?' do
    it 'allows admin users to update other users' do
      policy = described_class.new(admin_user, target_user)
      expect(policy.update?).to be true
    end

    it 'allows users to update themselves' do
      policy = described_class.new(regular_user, regular_user)
      expect(policy.update?).to be true
    end

    it 'denies regular users from updating other users' do
      policy = described_class.new(regular_user, target_user)
      expect(policy.update?).to be false
    end
  end

  describe '#edit?' do
    it 'allows admin users to edit other users' do
      policy = described_class.new(admin_user, target_user)
      expect(policy.edit?).to be true
    end

    it 'allows users to edit themselves' do
      policy = described_class.new(regular_user, regular_user)
      expect(policy.edit?).to be true
    end

    it 'denies regular users from editing other users' do
      policy = described_class.new(regular_user, target_user)
      expect(policy.edit?).to be false
    end
  end

  describe '#destroy?' do
    it 'allows admin users to destroy other users' do
      policy = described_class.new(admin_user, target_user)
      expect(policy.destroy?).to be true
    end

    it 'denies regular users from destroying other users' do
      policy = described_class.new(regular_user, target_user)
      expect(policy.destroy?).to be false
    end

    it 'denies users from destroying themselves' do
      policy = described_class.new(regular_user, regular_user)
      expect(policy.destroy?).to be false
    end
  end

  describe 'admin protection logic' do
    let(:other_admin) { build(:user, :admin) }

    describe '#destroy?' do
      context 'when target is an admin' do
        it 'allows admin to destroy other admins if not the last admin' do
          policy = described_class.new(admin_user, other_admin)
          expect(policy.destroy?).to be true
        end

        it 'denies admin from destroying themselves' do
          policy = described_class.new(admin_user, admin_user)
          expect(policy.destroy?).to be false
        end
      end
    end
  end

  describe '#manage_grants?' do
    it "allows an admin to manage a regular user's repository grants" do
      policy = described_class.new(admin_user, target_user)
      expect(policy.manage_grants?).to be true
    end

    it 'denies an admin managing grants for another admin' do
      policy = described_class.new(admin_user, build(:user, :admin))
      expect(policy.manage_grants?).to be false
    end

    it "denies a regular user managing another user's repository grants" do
      policy = described_class.new(regular_user, target_user)
      expect(policy.manage_grants?).to be false
    end

    it 'denies a regular user managing their own repository grants' do
      policy = described_class.new(regular_user, regular_user)
      expect(policy.manage_grants?).to be false
    end
  end
end
