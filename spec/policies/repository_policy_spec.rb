require 'rails_helper'

RSpec.describe RepositoryPolicy, type: :policy do
  subject { described_class }

  let(:admin_user) { build(:user, role: :admin) }
  let(:regular_user) { build(:user, role: :regular_user) }
  let(:repository) { build(:repository) }

  permissions :show? do
    it 'allows admin users to view repositories' do
      expect(subject).to permit(admin_user, repository)
    end

    it 'allows regular users to view repositories' do
      expect(subject).to permit(regular_user, repository)
    end
  end

  permissions :index? do
    it 'allows admin users to view repository list' do
      expect(subject).to permit(admin_user, Repository)
    end

    it 'allows regular users to view repository list' do
      expect(subject).to permit(regular_user, Repository)
    end
  end

  permissions :create? do
    it 'allows admin users to create repositories' do
      expect(subject).to permit(admin_user, Repository)
    end

    it 'denies regular users from creating repositories' do
      expect(subject).not_to permit(regular_user, Repository)
    end
  end

  permissions :new? do
    it 'allows admin users to access new repository form' do
      expect(subject).to permit(admin_user, Repository)
    end

    it 'denies regular users from accessing new repository form' do
      expect(subject).not_to permit(regular_user, Repository)
    end
  end

  permissions :update? do
    it 'allows admin users to update repositories' do
      expect(subject).to permit(admin_user, repository)
    end

    it 'denies regular users from updating repositories' do
      expect(subject).not_to permit(regular_user, repository)
    end
  end

  permissions :edit? do
    it 'allows admin users to edit repositories' do
      expect(subject).to permit(admin_user, repository)
    end

    it 'denies regular users from editing repositories' do
      expect(subject).not_to permit(regular_user, repository)
    end
  end

  permissions :destroy? do
    it 'allows admin users to destroy repositories' do
      expect(subject).to permit(admin_user, repository)
    end

    it 'denies regular users from destroying repositories' do
      expect(subject).not_to permit(regular_user, repository)
    end
  end

  permissions :sync? do
    it 'allows admin users to sync repositories' do
      expect(subject).to permit(admin_user, repository)
    end

    it 'denies regular users from syncing repositories' do
      expect(subject).not_to permit(regular_user, repository)
    end
  end
end