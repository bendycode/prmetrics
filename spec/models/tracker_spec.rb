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

  describe 'a Shortcut tracker' do
    subject(:tracker) { build(:tracker, :shortcut) }

    it { is_expected.to validate_presence_of(:api_token) }
    it { is_expected.to validate_presence_of(:workflow_id) }
    it { is_expected.to validate_absence_of(:source_repository) }
    it { is_expected.to allow_value('500', '1').for(:workflow_id) }
    it { is_expected.not_to allow_value('owner/repo', '12x', '-1', '0500', '0').for(:workflow_id) }

    it 'refuses a second tracker for a workflow even when the first was saved past its checks' do
      create(:tracker, :shortcut, workflow_id: '500')
      duplicate = build(:tracker, :shortcut, workflow_id: '500')

      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'refuses a workflow another Shortcut tracker reads, which would count its stories twice' do
      create(:tracker, :shortcut, workflow_id: '500')
      tracker.workflow_id = '500'

      expect(tracker).not_to be_valid
      expect(tracker.errors[:workflow_id]).to include('is already read by another Shortcut tracker')
    end

    it 'reads every team\'s stories unless limited to some' do
      expect(tracker.reads_team?('team-9')).to be(true)

      tracker.team_ids = ['team-1']

      expect([tracker.reads_team?('team-1'), tracker.reads_team?('team-9')]).to eq([true, false])
    end

    it 'is valid with a token and a workflow alone' do
      expect(tracker).to be_valid
    end

    it 'keeps its token unreadable in the database' do
      tracker.update!(api_token: 'shortcut-token-1234')

      stored = described_class.connection.select_value(
        described_class.where(id: tracker.id).select(:api_token).to_sql
      )
      expect(stored).not_to include('shortcut-token-1234')
      expect(tracker.reload.api_token).to eq('shortcut-token-1234')
    end

    # The filter_parameters entry for token does this, encrypts or not
    it 'leaves its token out of inspect' do
      tracker.api_token = 'shortcut-token-1234'

      expect(tracker.inspect).not_to include('shortcut-token-1234')
    end
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
      allow(GithubIssueSync).to receive(:new).with(tracker, full: false).and_return(sync)

      tracker.sync!

      expect(sync).to have_received(:sync!)
    end

    it 'asks the sync to read every story again when told to' do
      tracker = build(:tracker, :shortcut)
      sync = instance_double(ShortcutStorySync, sync!: nil)
      allow(ShortcutStorySync).to receive(:new).with(tracker, full: true).and_return(sync)

      tracker.sync!(full: true)

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
