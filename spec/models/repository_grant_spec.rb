require 'rails_helper'

RSpec.describe RepositoryGrant do
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:repository) }
  end

  describe 'validations' do
    subject { create(:repository_grant) }

    it { is_expected.to validate_uniqueness_of(:repository_id).scoped_to(:user_id) }
  end

  it 'rejects a duplicate user and repository pair at the database' do
    grant = create(:repository_grant)
    duplicate = described_class.new(user: grant.user, repository: grant.repository)

    expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  describe 'user and repository associations' do
    let(:user) { create(:user) }
    let(:repository) { create(:repository) }

    before { create(:repository_grant, user: user, repository: repository) }

    it 'lists granted repositories on the user' do
      expect(user.granted_repositories).to contain_exactly(repository)
    end

    it 'lists granted users on the repository' do
      expect(repository.granted_users).to contain_exactly(user)
    end

    it 'removes the grant when the user is destroyed' do
      expect { user.destroy }.to change(described_class, :count).by(-1)
    end

    it 'removes the grant when the repository is destroyed' do
      expect { repository.destroy }.to change(described_class, :count).by(-1)
    end
  end
end
