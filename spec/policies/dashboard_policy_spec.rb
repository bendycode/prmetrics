require 'rails_helper'

RSpec.describe DashboardPolicy, type: :policy do
  let(:admin_user) { build(:user, :admin) }
  let(:regular_user) { build(:user) }

  describe '#index?' do
    it 'allows admin users to view the dashboard' do
      policy = described_class.new(admin_user, :dashboard)
      expect(policy.index?).to be true
    end

    it 'allows regular users to view the dashboard' do
      policy = described_class.new(regular_user, :dashboard)
      expect(policy.index?).to be true
    end
  end
end
