require 'rails_helper'

RSpec.describe PullRequestPolicy, type: :policy do
  let(:parent) { build(:repository) }
  let(:record) { build(:pull_request, repository: parent) }

  describe '#show?' do
    it_behaves_like 'a policy that delegates show? to its parent', RepositoryPolicy
  end
end
