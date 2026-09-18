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

  describe 'Scope for a regular user' do
    let(:granted_repository) { create(:repository) }
    let(:granted_pull_request) { create(:pull_request, repository: granted_repository) }
    let(:ungranted_pull_request) { create(:pull_request, repository: create(:repository)) }
    let(:viewer) { create(:user) }
    let(:resolved) { described_class::Scope.new(viewer, Contributor).resolve }

    before { grant_access(viewer, granted_repository) }

    it 'includes reviewers of pull requests in granted repositories and no others' do
      visible_reviewer = create(:review, pull_request: granted_pull_request).author
      create(:review, pull_request: ungranted_pull_request)

      expect(resolved).to contain_exactly(granted_pull_request.author, visible_reviewer)
    end

    it 'includes participants in pull requests in granted repositories and no others' do
      visible_participant = create(:pull_request_user, pull_request: granted_pull_request).user
      create(:pull_request_user, pull_request: ungranted_pull_request)

      expect(resolved).to contain_exactly(granted_pull_request.author, visible_participant)
    end

    it 'excludes a contributor with no activity in any repository' do
      create(:contributor)

      expect(resolved).to contain_exactly(granted_pull_request.author)
    end

    it 'lists a contributor once when they have several kinds of activity' do
      author = granted_pull_request.author
      create(:review, pull_request: granted_pull_request, author: author)
      create(:pull_request_user, pull_request: granted_pull_request, user: author)

      expect(resolved.where(id: author.id).count).to eq(1)
    end
  end
end
