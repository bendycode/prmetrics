require 'rails_helper'

RSpec.describe ReviewPolicy, type: :policy do
  let(:parent) { build(:pull_request) }
  let(:record) { build(:review, pull_request: parent) }

  describe '#show?' do
    it_behaves_like 'a policy that delegates show? to its parent', PullRequestPolicy
  end
end
