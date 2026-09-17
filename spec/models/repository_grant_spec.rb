require 'rails_helper'

RSpec.describe RepositoryGrant do
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:repository) }
  end

  describe 'uniqueness of a user and repository pair' do
    subject(:grant) { create(:repository_grant) }

    it { is_expected.to validate_uniqueness_of(:repository_id).scoped_to(:user_id) }

    it 'is enforced by the database when validation is skipped' do
      duplicate = build(:repository_grant, user: grant.user, repository: grant.repository)

      expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe 'granting a user a repository' do
    let(:user) { create(:user) }
    let(:repository) { create(:repository) }

    before { create(:repository_grant, user: user, repository: repository) }

    it 'lists the repository among the user\'s granted repositories' do
      expect(user.granted_repositories).to contain_exactly(repository)
    end

    it 'is removed when the user is destroyed' do
      expect { user.destroy }.to change(described_class, :count).by(-1)
    end

    it 'is removed when the repository is destroyed' do
      expect { repository.destroy }.to change(described_class, :count).by(-1)
    end
  end
end
