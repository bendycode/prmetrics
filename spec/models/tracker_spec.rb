require 'rails_helper'

RSpec.describe Tracker do
  describe 'associations' do
    it { is_expected.to belong_to(:source_repository).class_name('Repository').optional }
    it { is_expected.to have_many(:repositories).dependent(:nullify) }
    it { is_expected.to have_many(:stories).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:tracker) }

    it { is_expected.to validate_presence_of(:source_repository) }
    it { is_expected.to validate_presence_of(:kind) }
    it { is_expected.to allow_value('PRM', 'A1').for(:key_prefix) }
    it { is_expected.not_to allow_value('prm', 'PRM-', 'P M').for(:key_prefix) }
  end

  describe '#story_key' do
    it 'uses the project\'s key prefix' do
      expect(build(:tracker, key_prefix: 'PRM').story_key(79)).to eq('PRM-79')
    end

    it 'falls back to GitHub\'s number without one' do
      expect(build(:tracker).story_key(79)).to eq('#79')
    end
  end

  it 'describes every kind the kind enum allows' do
    expect(described_class::KINDS.keys).to match_array(described_class.kinds.keys)
  end

  describe '#sync!' do
    it 'syncs a GitHub issues tracker through the GitHub issue sync' do
      tracker = build(:tracker)
      sync = instance_double(GithubIssueSync, sync!: nil)
      allow(GithubIssueSync).to receive(:new).with(tracker).and_return(sync)

      tracker.sync!

      expect(sync).to have_received(:sync!)
    end
  end

  describe 'one tracker per source repository' do
    subject(:tracker) { create(:tracker) }

    it { is_expected.to validate_uniqueness_of(:source_repository_id).allow_nil }
  end

  describe '.visible_to' do
    let(:granted_repository) { create(:repository) }
    let!(:granted) { create(:tracker, :covering_source, source_repository: granted_repository) }
    let!(:other) { create(:tracker, :covering_source) }

    it 'returns every tracker for an admin' do
      expect(described_class.visible_to(create(:user, :admin))).to contain_exactly(granted, other)
    end

    it 'returns the trackers covering a regular user\'s granted repositories' do
      user = create(:user)
      grant_access(user, granted_repository)

      expect(described_class.visible_to(user)).to contain_exactly(granted)
    end

    it 'returns a tracker once though the user was granted several of its repositories' do
      user = create(:user)
      grant_access(user, granted_repository, create(:repository, tracker: granted))

      expect(described_class.visible_to(user).to_a).to eq([granted])
    end
  end
end
