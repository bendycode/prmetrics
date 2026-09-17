# For a policy whose records belong to a repository. The including group
# defines let(:granted_repository), let(:record_in_granted), and
# let(:record_in_ungranted), where the two records belong to a repository
# the regular user was granted and one they were not.
RSpec.shared_examples 'a policy limited to granted repositories' do
  let(:admin_user) { create(:user, :admin) }
  let(:regular_user) { create(:user) }

  before { grant_access(regular_user, granted_repository) }

  describe 'Scope' do
    def resolved_for(user)
      described_class::Scope.new(user, record_in_granted.class).resolve
    end

    it 'includes records from every repository for an admin' do
      expect(resolved_for(admin_user)).to include(record_in_granted, record_in_ungranted)
    end

    it "includes only records from a regular user's granted repositories" do
      expect(resolved_for(regular_user)).to include(record_in_granted)
      expect(resolved_for(regular_user)).not_to include(record_in_ungranted)
    end

    it 'includes nothing for a regular user with no grants' do
      expect(resolved_for(create(:user))).to be_empty
    end
  end

  describe '#show?' do
    it 'allows an admin to see a record in any repository' do
      expect(described_class.new(admin_user, record_in_ungranted).show?).to be true
    end

    it 'allows a regular user to see a record in a granted repository' do
      expect(described_class.new(regular_user, record_in_granted).show?).to be true
    end

    it 'denies a regular user a record in an ungranted repository' do
      expect(described_class.new(regular_user, record_in_ungranted).show?).to be false
    end
  end
end
