require 'rails_helper'
require_relative '../../../db/data/20260917104413_grant_existing_users_repository_access'

RSpec.describe GrantExistingUsersRepositoryAccess do
  let(:migration) { described_class.new }
  let!(:first_repository) { create(:repository) }
  let!(:second_repository) { create(:repository) }
  let!(:regular_user) { create(:user) }
  let!(:pending_user) { create(:user, :pending) }
  let!(:admin) { create(:user, :admin) }

  around { |example| ActiveRecord::Migration.suppress_messages(&example) }

  describe '#up' do
    it 'grants every repository to every regular user, including one with a pending invitation',
       :aggregate_failures do
      migration.up

      expect(regular_user.granted_repositories).to contain_exactly(first_repository, second_repository)
      expect(pending_user.granted_repositories).to contain_exactly(first_repository, second_repository)
    end

    it 'grants admins nothing' do
      migration.up

      expect(admin.granted_repositories).to be_empty
    end

    it 'keeps a grant made beforehand and adds only the missing ones', :aggregate_failures do
      existing_grant = create(:repository_grant, user: regular_user, repository: first_repository)

      expect { migration.up }.to change(RepositoryGrant, :count).by(3)
      expect(RepositoryGrant.exists?(existing_grant.id)).to be(true)
      expect(regular_user.granted_repositories).to contain_exactly(first_repository, second_repository)
    end

    it 'adds nothing when run a second time' do
      migration.up

      expect { migration.up }.not_to change(RepositoryGrant, :count)
    end
  end
end
