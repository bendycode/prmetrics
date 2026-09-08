require 'rails_helper'

RSpec.describe PullRequestUserPolicy, type: :policy do
  let(:admin_user) { build(:user, :admin) }
  let(:regular_user) { build(:user) }
  let(:repository) { build(:repository) }
  let(:pull_request) { build(:pull_request, repository: repository) }
  let(:pull_request_user) { build(:pull_request_user, pull_request: pull_request) }

  describe '#show?' do
    it 'allows admin users to view pull request participants' do
      policy = described_class.new(admin_user, pull_request_user)
      expect(policy.show?).to be true
    end

    it 'allows regular users to view pull request participants' do
      policy = described_class.new(regular_user, pull_request_user)
      expect(policy.show?).to be true
    end

    it 'denies viewing when the pull request policy denies the owning pull request' do
      denying_policy = instance_double(PullRequestPolicy, show?: false)
      allow(PullRequestPolicy).to receive(:new).with(regular_user, pull_request).and_return(denying_policy)

      policy = described_class.new(regular_user, pull_request_user)
      expect(policy.show?).to be false
    end
  end
end
