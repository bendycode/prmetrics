require 'rails_helper'

RSpec.describe RepositoryPolicy, type: :policy do
  let(:admin_user) { build(:user, :admin) }
  let(:regular_user) { build(:user) }
  let(:repository) { build(:repository) }

  describe '#show?' do
    it 'allows admin users to view repositories' do
      policy = RepositoryPolicy.new(admin_user, repository)
      expect(policy.show?).to be true
    end

    it 'allows regular users to view repositories' do
      policy = RepositoryPolicy.new(regular_user, repository)
      expect(policy.show?).to be true
    end
  end

  describe '#index?' do
    it 'allows admin users to view repository list' do
      policy = RepositoryPolicy.new(admin_user, Repository)
      expect(policy.index?).to be true
    end

    it 'allows regular users to view repository list' do
      policy = RepositoryPolicy.new(regular_user, Repository)
      expect(policy.index?).to be true
    end
  end

  describe '#create?' do
    it 'allows admin users to create repositories' do
      policy = RepositoryPolicy.new(admin_user, Repository)
      expect(policy.create?).to be true
    end

    it 'denies regular users from creating repositories' do
      policy = RepositoryPolicy.new(regular_user, Repository)
      expect(policy.create?).to be false
    end
  end

  describe '#new?' do
    it 'allows admin users to access new repository form' do
      policy = RepositoryPolicy.new(admin_user, Repository)
      expect(policy.new?).to be true
    end

    it 'denies regular users from accessing new repository form' do
      policy = RepositoryPolicy.new(regular_user, Repository)
      expect(policy.new?).to be false
    end
  end

  describe '#update?' do
    it 'allows admin users to update repositories' do
      policy = RepositoryPolicy.new(admin_user, repository)
      expect(policy.update?).to be true
    end

    it 'denies regular users from updating repositories' do
      policy = RepositoryPolicy.new(regular_user, repository)
      expect(policy.update?).to be false
    end
  end

  describe '#edit?' do
    it 'allows admin users to edit repositories' do
      policy = RepositoryPolicy.new(admin_user, repository)
      expect(policy.edit?).to be true
    end

    it 'denies regular users from editing repositories' do
      policy = RepositoryPolicy.new(regular_user, repository)
      expect(policy.edit?).to be false
    end
  end

  describe '#destroy?' do
    it 'allows admin users to destroy repositories' do
      policy = RepositoryPolicy.new(admin_user, repository)
      expect(policy.destroy?).to be true
    end

    it 'denies regular users from destroying repositories' do
      policy = RepositoryPolicy.new(regular_user, repository)
      expect(policy.destroy?).to be false
    end
  end

  describe '#sync?' do
    it 'allows admin users to sync repositories' do
      policy = RepositoryPolicy.new(admin_user, repository)
      expect(policy.sync?).to be true
    end

    it 'denies regular users from syncing repositories' do
      policy = RepositoryPolicy.new(regular_user, repository)
      expect(policy.sync?).to be false
    end
  end
end