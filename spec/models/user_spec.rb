require 'rails_helper'

RSpec.describe User do
  describe 'associations' do
    # User model is for authentication/authorization only
    # No associations with pull requests, reviews, or GitHub data
  end

  describe 'validations' do
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }

    context 'with valid user attributes' do
      subject { build(:user) }

      it { should validate_presence_of(:role) }
    end
  end

  describe 'enums' do
    it { should define_enum_for(:role).with_values(regular_user: 0, admin: 1).with_default(:regular_user) }
  end

  describe 'devise modules' do
    it 'includes required devise modules' do
      expected_modules = [:invitable, :database_authenticatable, :recoverable,
                         :rememberable, :validatable, :trackable]
      expect(User.devise_modules).to include(*expected_modules)
    end
  end

  describe 'default values' do
    it 'defaults to regular_user role' do
      expect(build(:user).role).to eq('regular_user')
    end
  end

  describe 'role methods' do
    let(:admin_user) { build(:user, :admin) }
    let(:regular_user) { build(:user) }

    describe '#admin?' do
      it 'returns true for admin users' do
        expect(admin_user.admin?).to be true
      end

      it 'returns false for regular users' do
        expect(regular_user.admin?).to be false
      end
    end

    describe '#regular_user?' do
      it 'returns false for admin users' do
        expect(admin_user.regular_user?).to be false
      end

      it 'returns true for regular users' do
        expect(regular_user.regular_user?).to be true
      end
    end
  end

  describe 'scopes' do
    before do
      create(:user, :admin)
      create(:user)
      create(:user, :admin)
    end

    describe '.admin' do
      it 'returns only admin users' do
        expect(User.admin.count).to eq(2)
        expect(User.admin.all? { |u| u.admin? }).to be true
      end
    end

    describe '.regular_user' do
      it 'returns only regular users' do
        expect(User.regular_user.count).to eq(1)
        expect(User.regular_user.all? { |u| u.regular_user? }).to be true
      end
    end
  end

  describe 'invitation behavior' do
    it 'can be invited' do
      user = User.invite!(email: 'test@example.com')
      expect(user).to be_persisted
      expect(user.invitation_sent_at).to be_present
    end

    it 'can set role during invitation' do
      admin = User.invite!(email: 'admin@example.com', role: :admin)
      expect(admin.role).to eq('admin')

      regular = User.invite!(email: 'regular@example.com', role: :regular_user)
      expect(regular.role).to eq('regular_user')
    end
  end

  describe 'admin protection' do
    let!(:admin1) { create(:user, :admin) }
    let!(:admin2) { create(:user, :admin) }
    let!(:regular_user) { create(:user) }

    describe '.last_admin?' do
      it 'returns true when there is only one admin' do
        admin2.destroy
        expect(User.last_admin?(admin1)).to be true
      end

      it 'returns false when there are multiple admins' do
        expect(User.last_admin?(admin1)).to be false
        expect(User.last_admin?(admin2)).to be false
      end

      it 'returns false for regular users' do
        expect(User.last_admin?(regular_user)).to be false
      end
    end
  end

end
