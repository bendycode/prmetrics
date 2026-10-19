require 'rails_helper'

RSpec.describe StoryTimes do
  let(:day0) { Time.zone.parse('2026-09-01 10:00') }
  let(:triggers) { Tracker::KINDS.fetch('github_issues')[:triggers] }

  def event(kind, day, payload = {})
    StoryEvent.new(kind: kind, occurred_at: day0 + day.days, payload: payload)
  end

  def times(events, state_reason: 'completed')
    described_class.new(events: events, triggers: triggers, state_reason: state_reason)
  end

  describe 'started' do
    it 'takes the earliest matching event, whichever kind it is' do
      result = times([event(:opened, 0), event(:assigned, 5), event(:commit_referenced, 2), event(:closed, 9)])

      expect(result).to have_attributes(started_at: day0 + 2.days, started_source: :commit_referenced)
    end

    it 'falls back to a pull request link when nothing else started the work' do
      result = times([event(:opened, 0), event(:pull_request_linked, 3), event(:closed, 6)])

      expect(result).to have_attributes(started_at: day0 + 3.days, started_source: :pull_request_linked)
    end

    it 'is unknown when no event started the work' do
      result = times([event(:opened, 0), event(:closed, 4)])

      expect(result).to have_attributes(started_at: nil, started_source: nil)
    end

    it 'ignores events after the work was done' do
      result = times([event(:opened, 0), event(:closed, 4), event(:commit_referenced, 5)])

      expect(result).to have_attributes(started_at: nil, started_source: nil)
    end
  end

  describe 'committed' do
    it 'is when the story was opened' do
      result = times([event(:opened, 1), event(:assigned, 3), event(:closed, 4)])

      expect(result).to have_attributes(committed_at: day0 + 1.day, committed_source: :opened)
    end

    it 'moves back to the started time when the work started before it was committed to' do
      result = times([event(:commit_referenced, 1), event(:opened, 2), event(:closed, 4)])

      expect(result).to have_attributes(committed_at: day0 + 1.day, committed_source: :commit_referenced)
    end
  end

  describe 'done' do
    it 'is the close of a story closed as completed' do
      expect(times([event(:opened, 0), event(:closed, 4)]).done_at).to eq(day0 + 4.days)
    end

    it 'is the last close when the story was reopened and closed again' do
      result = times([event(:opened, 0), event(:closed, 2), event(:reopened, 3), event(:closed, 6)])

      expect(result.done_at).to eq(day0 + 6.days)
    end

    # Read from the events alone: the issue's reason is left at completed.
    it 'is not reached while a reopened story is still open' do
      result = times([event(:opened, 0), event(:closed, 2), event(:reopened, 3)])

      expect(result.done_at).to be_nil
    end

    it 'is never reached by a story closed as not planned' do
      expect(times([event(:opened, 0), event(:closed, 4)], state_reason: 'not_planned').done_at).to be_nil
    end

    it 'is never reached by a story closed as a duplicate' do
      expect(times([event(:opened, 0), event(:closed, 4)], state_reason: 'duplicate').done_at).to be_nil
    end

    # GitHub records no reason on issues closed before it began recording them
    it 'is reached by a close GitHub recorded no reason for' do
      expect(times([event(:opened, 0), event(:closed, 4)], state_reason: nil).done_at).to eq(day0 + 4.days)
    end

    it 'counts events that arrive in any order' do
      result = times([event(:closed, 6), event(:reopened, 3), event(:closed, 2), event(:opened, 0)])

      expect(result.done_at).to eq(day0 + 6.days)
    end
  end

  describe 'triggers with conditions on the payload' do
    let(:triggers) do
      { committed: [StoryTrigger[:opened]],
        started: [StoryTrigger[:assigned, 'assignee' => { 'type' => 'User' }]],
        done: { close: [StoryTrigger[:closed]], reopen: [StoryTrigger[:reopened]] } }
    end

    it 'starts at the first event whose payload matches' do
      result = times([event(:opened, 0), event(:assigned, 1, 'assignee' => { 'type' => 'Bot' }),
                      event(:assigned, 3, 'assignee' => { 'type' => 'User' }), event(:closed, 5)])

      expect(result).to have_attributes(started_at: day0 + 3.days, started_source: :assigned)
    end
  end

  describe 'done rules' do
    let(:triggers) do
      { committed: [StoryTrigger[:opened]], started: [StoryTrigger[:assigned]],
        done: { close: [StoryTrigger[:pull_request_linked]], reopen: [StoryTrigger[:commit_referenced]] } }
    end

    it 'closes and reopens on the events the tracker kind names' do
      result = times([event(:opened, 0), event(:pull_request_linked, 2), event(:commit_referenced, 3),
                      event(:pull_request_linked, 5), event(:closed, 6)])

      expect(result.done_at).to eq(day0 + 5.days)
    end

    it 'is not reached while the kind\'s reopen is the last word' do
      result = times([event(:opened, 0), event(:pull_request_linked, 2), event(:commit_referenced, 3), event(:closed, 4)])

      expect(result.done_at).to be_nil
    end
  end

  # Measured over story histories read the way the Shortcut sync reads them
  context "with a Shortcut tracker's triggers" do
    let(:triggers) { Tracker::KINDS.fetch('shortcut')[:triggers] }
    let(:workflow) { shortcut_fixture('workflow') }

    def shortcut_times(history, story_id, in_workflow: workflow)
      history = shortcut_fixture(history) if history.is_a?(String)
      events = ShortcutStoryHistory.new(story_id: story_id, workflow: in_workflow, history: history).events
      described_class.new(events: events.map { |attributes| StoryEvent.new(attributes) }, triggers: triggers,
                          state_reason: nil)
    end

    def at(time)
      Time.zone.parse(time)
    end

    it 'is committed when the story reaches Ready, started when it reaches a started state, and done on the last move into a done one' do
      expect(shortcut_times('history_7001', 7001)).to have_attributes(
        committed_at: at('2026-09-03T15:00:00Z'), committed_source: :status_changed,
        started_at: at('2026-09-05T15:00:00Z'), started_source: :status_changed,
        done_at: at('2026-09-12T16:00:00Z')
      )
    end

    it 'is done only at the last move into a done state after a move back to work' do
      expect(shortcut_times('history_reopened', 7005).done_at).to eq(at('2026-09-09T15:00:00Z'))
    end

    # Work waiting in refinement was never committed to
    it 'is committed on reaching the last unstarted state, not on leaving the first' do
      workflow = { 'states' => [{ 'id' => 1, 'type' => 'backlog', 'position' => 0, 'name' => 'New' },
                                { 'id' => 2, 'type' => 'unstarted', 'position' => 1, 'name' => 'Refining' },
                                { 'id' => 3, 'type' => 'unstarted', 'position' => 2, 'name' => 'Ready' },
                                { 'id' => 4, 'type' => 'started', 'position' => 3, 'name' => 'Doing' },
                                { 'id' => 5, 'type' => 'done', 'position' => 4, 'name' => 'Done' }] }
      move = lambda do |id, day, from, to|
        { 'id' => id, 'changed_at' => "2026-09-0#{day}T15:00:00Z",
          'actions' => [{ 'id' => 9, 'entity_type' => 'story', 'action' => 'update',
                          'changes' => { 'workflow_state_id' => { 'old' => from, 'new' => to } } }] }
      end
      history = [move.call('m1', 1, 1, 2), move.call('m2', 3, 2, 3), move.call('m3', 5, 3, 4), move.call('m4', 8, 4, 5)]
      expect(shortcut_times(history, 9, in_workflow: workflow).committed_at).to eq(at('2026-09-03T15:00:00Z'))
    end

    it 'is never committed for a story that went straight to done' do
      history = [{ 'id' => 's1', 'changed_at' => '2026-09-01T15:00:00Z',
                   'actions' => [{ 'id' => 9, 'entity_type' => 'story', 'action' => 'create', 'workflow_state_id' => 101 }] },
                 { 'id' => 's2', 'changed_at' => '2026-09-04T15:00:00Z',
                   'actions' => [{ 'id' => 9, 'entity_type' => 'story', 'action' => 'update',
                                   'changes' => { 'workflow_state_id' => { 'old' => 101, 'new' => 105 } } }] }]
      expect(shortcut_times(history, 9)).to have_attributes(committed_at: nil, done_at: at('2026-09-04T15:00:00Z'))
    end

    # As when finished work is logged after the fact
    it 'is done at creation for a story created in a done state' do
      history = [{ 'id' => 'd1', 'changed_at' => '2026-09-02T15:00:00Z',
                   'actions' => [{ 'id' => 9, 'entity_type' => 'story', 'action' => 'create', 'workflow_state_id' => 105 }] }]
      expect(shortcut_times(history, 9)).to have_attributes(done_at: at('2026-09-02T15:00:00Z'), committed_at: nil)
    end

    it 'is committed at creation for a story created past the first state' do
      expect(shortcut_times('history_created_ready', 7006)).to have_attributes(
        committed_at: at('2026-09-01T15:00:00Z'), committed_source: :opened, started_at: at('2026-09-02T15:00:00Z')
      )
    end

    it 'falls back to a commit for the start when no move reached a started state' do
      expect(shortcut_times('history_code_only', 7007)).to have_attributes(
        started_at: at('2026-09-02T15:00:00Z'), started_source: :commit_referenced,
        done_at: at('2026-09-03T15:00:00Z')
      )
    end

    it 'is not done while the story sits in a started state' do
      expect(shortcut_times(shortcut_fixture('history_reopened').first(4), 7005).done_at).to be_nil
    end
  end
end
