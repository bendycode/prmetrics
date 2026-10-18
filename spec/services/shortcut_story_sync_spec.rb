require 'rails_helper'

RSpec.describe ShortcutStorySync do
  let(:tracker) { create(:tracker, :shortcut, workflow_id: '100') }
  let(:shortcut) { instance_double(ShortcutService) }
  let(:sync) { described_class.new(tracker, shortcut: shortcut) }

  # A fixture history told about another story, as Shortcut would tell it
  def history_for(story_id, name = 'history_7001')
    JSON.parse(shortcut_json(name).gsub('7001', story_id.to_s))
  end

  before do
    allow(shortcut).to receive(:workflow).with('100').and_return(shortcut_fixture('workflow'))
    allow(shortcut).to receive(:stories_in_state).and_return([])
    allow(shortcut).to receive(:stories_in_state).with(105).and_return(shortcut_fixture('search_state_105'))
    allow(shortcut).to receive(:stories_in_state).with(103).and_return(shortcut_fixture('search_state_103'))
    allow(shortcut).to receive(:history).with(7001).and_return(shortcut_fixture('history_7001'))
    allow(shortcut).to receive(:history).with(7002).and_return(history_for(7002))
    allow(shortcut).to receive(:history).with(7003).and_return(history_for(7003).first(5))
  end

  it 'stores every story in the workflow, keyed sc-NNNN, open or closed by the type of state it is in' do
    sync.sync!

    expect(tracker.stories.order(:external_id).pluck(:external_id, :key, :state)).to eq(
      [%w[7001 sc-7001 closed], %w[7002 sc-7002 closed], %w[7003 sc-7003 open]]
    )
    expect(tracker.stories.find_by(external_id: '7001'))
      .to have_attributes(title: 'Story 7001', url: 'https://app.shortcut.com/example/story/7001')
  end

  it 'measures each story from its history' do
    sync.sync!

    expect(tracker.stories.find_by(external_id: '7001')).to have_attributes(
      committed_at: Time.zone.parse('2026-09-03T15:00:00Z'), committed_source: 'status_changed',
      started_at: Time.zone.parse('2026-09-05T15:00:00Z'), done_at: Time.zone.parse('2026-09-12T16:00:00Z')
    )
  end

  # Teams archive finished stories to tidy their board
  it 'counts a story archived after it was finished' do
    sync.sync!

    expect(tracker.stories.finished.pluck(:external_id)).to contain_exactly('7001', '7002')
  end

  it 'leaves out a story archived before it was finished' do
    abandoned = shortcut_fixture('story_7001').merge('id' => 7009, 'workflow_state_id' => 103, 'archived' => true)
    allow(shortcut).to receive(:stories_in_state).with(103).and_return([abandoned])
    allow(shortcut).to receive(:history).with(7009).and_return(history_for(7009, 'history_reopened').first(4))

    sync.sync!

    expect(tracker.stories.find_by(external_id: '7009')).to have_attributes(state_reason: 'archived', done_at: nil)
  end

  it 'skips the history of a story stored at the update Shortcut lists, once listed after it' do
    sync.sync!

    described_class.new(tracker, shortcut: shortcut).sync!

    expect(shortcut).to have_received(:history).with(7001).once
  end

  # Moving or adding a state changes what a story's moves mean without touching the story
  it "reads every story again once the workflow's states have changed" do
    sync.sync!
    changed = shortcut_fixture('workflow')
    changed['states'] += [changed['states'].last.merge('id' => 107, 'position' => 99)]
    allow(shortcut).to receive(:workflow).with('100').and_return(changed)

    described_class.new(tracker, shortcut: shortcut).sync!

    expect(shortcut).to have_received(:history).with(7001).twice
  end

  it 'keeps a team limit set while the sync runs' do
    allow(shortcut).to receive(:stories_in_state).with(105) do
      Tracker.find(tracker.id).update!(team_ids: ['team-1'])
      shortcut_fixture('search_state_105')
    end

    sync.sync!

    expect(Tracker.find(tracker.id).team_ids).to eq(['team-1'])
  end

  it 'reads every story again when told to, changed or not' do
    sync.sync!

    described_class.new(tracker, shortcut: shortcut, full: true).sync!

    expect(shortcut).to have_received(:history).with(7001).twice
  end

  # Shortcut's times are whole seconds, and its clock and this app's can drift
  it 'reads a story again when it was stored before Shortcut listed its update' do
    create(:story, tracker: tracker, external_id: '7001', source_updated_at: '2026-09-12T16:00:00Z',
                   listed_at: '2026-09-12T16:00:00Z')

    sync.sync!

    expect(shortcut).to have_received(:history).with(7001)
  end

  it 'reads a changed story again, storing each event once' do
    sync.sync!
    moved = shortcut_fixture('search_state_105').map { |story| story.merge('updated_at' => '2026-10-02T16:00:00Z') }
    allow(shortcut).to receive(:stories_in_state).with(105).and_return(moved)

    expect { described_class.new(tracker, shortcut: shortcut).sync! }.not_to change(StoryEvent, :count)
    expect(shortcut).to have_received(:history).with(7001).twice
  end

  it 'stores the other stories when one cannot be read, then reports it' do
    allow(shortcut).to receive(:history).with(7002).and_raise(ShortcutService::Error, 'Shortcut answered 500')

    expect { sync.sync! }.to raise_error(described_class::StoriesFailed, /sc-7002/)
    expect(tracker.stories.pluck(:external_id)).to contain_exactly('7001', '7003')
  end

  # Each request already retried for two minutes; an outage would otherwise cost that per story
  it 'stops after three stories in a row cannot be read' do
    many = (1..6).map { |n| shortcut_fixture('story_7001').merge('id' => 7100 + n) }
    allow(shortcut).to receive(:stories_in_state).with(105).and_return(many)
    allow(shortcut).to receive(:stories_in_state).with(103).and_return([])
    allow(shortcut).to receive(:history).and_raise(ShortcutService::Error, 'Shortcut answered 503')

    expect { sync.sync! }.to raise_error(described_class::StoriesFailed, /stopped after 3 failures in a row/)
    expect(shortcut).to have_received(:history).exactly(3).times
  end

  # The production log reaches the nightly workflow's public log, and a story's number is the workspace's own
  it 'counts failures in a row again after a story is stored' do
    many = (1..5).map { |n| shortcut_fixture('story_7001').merge('id' => 7100 + n) }
    allow(shortcut).to receive(:stories_in_state).with(105).and_return(many)
    allow(shortcut).to receive(:stories_in_state).with(103).and_return([])
    allow(shortcut).to receive(:history).and_raise(ShortcutService::Error, 'Shortcut answered 503')
    allow(shortcut).to receive(:history).with(7103).and_return(shortcut_fixture('history_7001'))
    allow(shortcut).to receive(:story)

    expect { sync.sync! }.to raise_error(described_class::StoriesFailed) { |error|
      expect(error.message).not_to include('stopped')
    }
    expect(shortcut).to have_received(:history).exactly(5).times
  end

  it 'logs a failure by tracker and error class, never the story or the message' do
    allow(Rails.logger).to receive(:error)
    allow(shortcut).to receive(:history).with(7002).and_raise(ShortcutService::Error, 'Shortcut answered 500 to GET x')

    expect { sync.sync! }.to raise_error(described_class::StoriesFailed)
    expect(Rails.logger).to have_received(:error)
      .with("Story sync could not store a story of tracker #{tracker.id}: ShortcutService::Error")
  end

  describe 'for a tracker limited to some teams' do
    let(:other_team) { shortcut_fixture('story_7001').merge('id' => 7008, 'group_id' => 'team-2') }

    before do
      tracker.update!(team_ids: ['team-1'])
      allow(shortcut).to receive(:stories_in_state).with(105).and_return(shortcut_fixture('search_state_105') + [other_team])
    end

    it 'stores only the stories of those teams' do
      sync.sync!

      expect(tracker.stories.pluck(:external_id)).to contain_exactly('7001', '7002', '7003')
    end

    it 'marks a stored story gone once the listing shows it belongs to another team, without reading it again' do
      stored = create(:story, tracker: tracker, external_id: '7008', key: 'sc-7008')
      allow(shortcut).to receive(:story)

      sync.sync!

      expect(stored.reload).to be_gone
      expect(shortcut).not_to have_received(:story)
    end

    it 'marks a stored story gone once a direct read finds it belongs to another team' do
      allow(shortcut).to receive(:stories_in_state).with(105).and_return(shortcut_fixture('search_state_105'))
      stored = create(:story, tracker: tracker, external_id: '7008', key: 'sc-7008')
      allow(shortcut).to receive(:story).with(7008).and_return(other_team)

      sync.sync!

      expect(stored.reload).to be_gone
    end
  end

  describe 'a stored story the listing leaves out' do
    let!(:unlisted) { create(:story, tracker: tracker, external_id: '7004', key: 'sc-7004') }

    it 'is gone once Shortcut no longer has it' do
      allow(shortcut).to receive(:story).with(7004).and_return(nil)

      sync.sync!

      expect(unlisted.reload).to be_gone
    end

    it 'is gone once Shortcut has moved it to another workflow' do
      allow(shortcut).to receive(:story).with(7004).and_return(shortcut_fixture('story_moved_away'))

      sync.sync!

      expect(unlisted.reload).to be_gone
    end

    # The listing reads one state at a time, so a story moving between states can miss it
    it 'stays when Shortcut still has it in the workflow' do
      allow(shortcut).to receive(:story).with(7004).and_return(shortcut_fixture('story_7001').merge('id' => 7004))

      sync.sync!

      expect(unlisted.reload).not_to be_gone
    end

    it 'is reported when it cannot be read, after every story is measured' do
      allow(shortcut).to receive(:story).with(7004).and_raise(ShortcutService::Error, 'Shortcut answered 500')

      expect { sync.sync! }.to raise_error(described_class::StoriesFailed, /sc-7004/)
      expect(tracker.stories.find_by(external_id: '7001').done_at).to eq(Time.zone.parse('2026-09-12T16:00:00Z'))
      expect(unlisted.reload).not_to be_gone
    end

    it 'is not read when the run stopped on failures, which an outage would also make' do
      many = (1..3).map { |n| shortcut_fixture('story_7001').merge('id' => 7100 + n) }
      allow(shortcut).to receive(:stories_in_state).with(105).and_return(many)
      allow(shortcut).to receive(:history).and_raise(ShortcutService::Error, 'Shortcut answered 503')
      allow(shortcut).to receive(:story)

      expect { sync.sync! }.to raise_error(described_class::StoriesFailed)
      expect(shortcut).not_to have_received(:story)
    end
  end
end
