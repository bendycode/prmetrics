require 'rails_helper'

RSpec.describe ReviewPolicy, type: :policy do
  let(:admin_user) { build(:user, :admin) }
  let(:regular_user) { build(:user) }
  let(:repository) { build(:repository) }
  let(:pull_request) { build(:pull_request, repository: repository) }
  let(:review) { build(:review, pull_request: pull_request) }

  describe '#show?' do
    it 'allows admin users to view reviews' do
      policy = described_class.new(admin_user, review)
      expect(policy.show?).to be true
    end

    it 'allows regular users to view reviews' do
      policy = described_class.new(regular_user, review)
      expect(policy.show?).to be true
    end

    it 'denies viewing when the repository policy denies the owning repository' do
      denying_policy = instance_double(RepositoryPolicy, show?: false)
      allow(RepositoryPolicy).to receive(:new).with(regular_user, repository).and_return(denying_policy)

      policy = described_class.new(regular_user, review)
      expect(policy.show?).to be false
    end
  end
end
