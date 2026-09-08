require 'rails_helper'

RSpec.describe ContributorPolicy, type: :policy do
  let(:admin_user) { build(:user, :admin) }
  let(:regular_user) { build(:user) }
  let(:contributor) { build(:contributor) }

  describe '#index?' do
    it 'allows admin users to view the contributor list' do
      policy = described_class.new(admin_user, Contributor)
      expect(policy.index?).to be true
    end

    it 'allows regular users to view the contributor list' do
      policy = described_class.new(regular_user, Contributor)
      expect(policy.index?).to be true
    end
  end

  describe '#show?' do
    it 'allows admin users to view contributors' do
      policy = described_class.new(admin_user, contributor)
      expect(policy.show?).to be true
    end

    it 'allows regular users to view contributors' do
      policy = described_class.new(regular_user, contributor)
      expect(policy.show?).to be true
    end
  end
end
