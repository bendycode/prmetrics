# For a policy whose show? asks the parent record's policy. Define
# let(:record) and let(:parent) in the including group and pass the
# parent's policy class.
RSpec.shared_examples 'a policy that delegates show? to its parent' do |parent_policy|
  let(:admin_user) { build(:user, :admin) }
  let(:regular_user) { build(:user) }

  it 'allows admin users' do
    expect(described_class.new(admin_user, record).show?).to be true
  end

  it 'allows regular users' do
    expect(described_class.new(regular_user, record).show?).to be true
  end

  it 'denies when the parent policy denies' do
    deny_policy(parent_policy, :show?, regular_user, on: parent)

    expect(described_class.new(regular_user, record).show?).to be false
  end
end
