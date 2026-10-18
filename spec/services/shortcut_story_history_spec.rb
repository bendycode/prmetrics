require 'rails_helper'

RSpec.describe ShortcutStoryHistory do
  let(:workflow) { shortcut_fixture('workflow') }

  def events(name, story_id: 7001)
    described_class.new(story_id: story_id, workflow: workflow, history: shortcut_fixture(name)).events
  end

  def state(id, name, type, position, first: false)
    { 'id' => id, 'name' => name, 'type' => type, 'position' => position, 'first' => first }
  end

  it 'turns a finished story\'s history into the events cycle time is measured from, in order' do
    expect(events('history_7001').map { |event| [event[:kind], event[:occurred_at].utc.iso8601] }).to eq(
      [[:opened, '2026-09-01T15:00:00Z'], [:status_changed, '2026-09-03T15:00:00Z'],
       [:status_changed, '2026-09-05T15:00:00Z'], [:branch_linked, '2026-09-05T17:00:00Z'],
       [:pull_request_linked, '2026-09-08T15:00:00Z'], [:status_changed, '2026-09-08T15:00:00Z'],
       [:status_changed, '2026-09-12T16:00:00Z']]
    )
  end

  it 'records a status move\'s states, with the workflow\'s first state marked' do
    move = events('history_7001').find { |event| event[:kind] == :status_changed }

    expect(move[:payload]).to eq(
      'from' => state(101, 'Inbox', 'backlog', 0, first: true), 'to' => state(102, 'Ready', 'unstarted', 1)
    )
  end

  it 'records the state a story was created in' do
    created = events('history_created_ready', story_id: 7006).first

    expect(created).to include(kind: :opened, payload: { 'state' => state(102, 'Ready', 'unstarted', 1) })
  end

  it 'reads a commit as a commit reference' do
    expect(events('history_code_only', story_id: 7007).pluck(:kind))
      .to eq(%i[opened commit_referenced status_changed])
  end

  it 'gives every event an ID that stays the same on the next read' do
    ids = events('history_7001').pluck(:external_id)

    expect(ids).to eq(ids.uniq).and eq(events('history_7001').pluck(:external_id))
  end

  it 'takes a state outside the workflow from the entry\'s own record of it' do
    history = [{ 'id' => 'x-1', 'changed_at' => '2026-09-10T15:00:00Z',
                 'actions' => [{ 'id' => 7001, 'entity_type' => 'story', 'action' => 'update',
                                 'changes' => { 'workflow_state_id' => { 'old' => 105, 'new' => 301 } } }],
                 'references' => [{ 'id' => 301, 'entity_type' => 'workflow-state', 'name' => 'Elsewhere',
                                    'type' => 'started' }] }]

    to = described_class.new(story_id: 7001, workflow: workflow, history: history).events.sole[:payload]['to']

    expect(to).to eq(state(301, 'Elsewhere', 'started', nil))
  end

  it 'ignores what an entry records about other stories' do
    history = [{ 'id' => 'y-1', 'changed_at' => '2026-09-10T15:00:00Z',
                 'actions' => [{ 'id' => 7999, 'entity_type' => 'story', 'action' => 'update',
                                 'changes' => { 'workflow_state_id' => { 'old' => 101, 'new' => 103 } } }] }]

    expect(described_class.new(story_id: 7001, workflow: workflow, history: history).events).to be_empty
  end
end
