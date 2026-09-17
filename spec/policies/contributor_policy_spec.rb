require 'rails_helper'

RSpec.describe ContributorPolicy, type: :policy do
  let(:admin_user) { build(:user, :admin) }
  let(:regular_user) { build(:user) }

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

  it_behaves_like 'a policy limited to granted repositories' do
    let(:granted_repository) { create(:repository) }
    let(:record_in_granted) { create(:pull_request, repository: granted_repository).author }
    let(:record_in_ungranted) { create(:pull_request, repository: create(:repository)).author }
  end

  describe 'Scope' do
    let(:granted_repository) { create(:repository) }
    let(:granted_pull_request) { create(:pull_request, repository: granted_repository) }
    let(:regular_user) { create(:user) }
    let(:resolved) { described_class::Scope.new(regular_user, Contributor).resolve }

    before { grant_access(regular_user, granted_repository) }

    it 'includes a contributor who reviewed a pull request in a granted repository' do
      reviewer = create(:review, pull_request: granted_pull_request).author

      expect(resolved).to include(reviewer)
    end

    it 'includes a contributor who participated in a pull request in a granted repository' do
      participant = create(:pull_request_user, pull_request: granted_pull_request).user

      expect(resolved).to include(participant)
    end

    it 'excludes a contributor with no activity in any repository' do
      expect(resolved).not_to include(create(:contributor))
    end

    it 'lists a contributor once when they have several kinds of activity' do
      author = granted_pull_request.author
      create(:review, pull_request: granted_pull_request, author: author)
      create(:pull_request_user, pull_request: granted_pull_request, user: author)

      expect(resolved.where(id: author.id).count).to eq(1)
    end
  end
end
