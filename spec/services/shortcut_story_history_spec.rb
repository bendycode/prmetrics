require 'rails_helper'

RSpec.describe ShortcutStoryHistory do
  let(:workflow) { shortcut_fixture('workflow') }

  def events(name, story_id: 7001)
    described_class.new(story_id: story_id, workflow: workflow, history: shortcut_fixture(name)).events
  end

  def state(id, name, type, position, committed: false)
    { 'id' => id, 'name' => name, 'type' => type, 'position' => position, 'committed' => committed }
  end

  it 'turns a finished story\'s history into the events cycle time is measured from, in order' do
    expect(events('history_7001').map { |event| [event[:kind], event[:occurred_at].utc.iso8601] }).to eq(
      [[:opened, '2026-09-01T15:00:00Z'], [:status_changed, '2026-09-03T15:00:00Z'],
       [:status_changed, '2026-09-05T15:00:00Z'], [:branch_linked, '2026-09-05T17:00:00Z'],
       [:pull_request_linked, '2026-09-08T15:00:00Z'], [:status_changed, '2026-09-08T15:00:00Z'],
       [:status_changed, '2026-09-12T16:00:00Z']]
    )
  end

  # The workflow's last unstarted state, Ready here, is where its work is committed to
  it 'records a status move\'s states, each marked whether it is at or past commitment' do
    move = events('history_7001').find { |event| event[:kind] == :status_changed }

    expect(move[:payload]).to include(
      'from' => state(101, 'Inbox', 'backlog', 0), 'to' => state(102, 'Ready', 'unstarted', 1, committed: true)
    )
  end

  it 'records the state a story was created in' do
    created = events('history_created_ready', story_id: 7006).first

    expect(created).to include(kind: :opened)
    expect(created[:payload]).to include('state' => state(102, 'Ready', 'unstarted', 1, committed: true))
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

  # Positions are a workflow's own; a state in another workflow is never past this one's commitment
  it 'marks no state outside the workflow as committed, whatever position its reference gives' do
    history = [{ 'id' => 'x-2', 'changed_at' => '2026-09-10T15:00:00Z',
                 'actions' => [{ 'id' => 7001, 'entity_type' => 'story', 'action' => 'update',
                                 'changes' => { 'workflow_state_id' => { 'old' => 301, 'new' => 101 } } }],
                 'references' => [{ 'id' => 301, 'entity_type' => 'epic', 'name' => 'Not a state' },
                                  { 'id' => 301, 'entity_type' => 'workflow-state', 'name' => 'Elsewhere',
                                    'type' => 'backlog', 'position' => 0 }] }]

    from = described_class.new(story_id: 7001, workflow: workflow, history: history).events.sole[:payload]['from']

    expect(from).to include('name' => 'Elsewhere', 'committed' => false)
  end

  it 'keeps the action a status move came from, as Shortcut recorded it' do
    move = events('history_7001').find { |event| event[:kind] == :status_changed }

    expect(move[:payload]['action']).to include('entity_type' => 'story', 'action' => 'update')
  end

  it 'keeps the action a link came from, as Shortcut recorded it' do
    branch = events('history_7001').find { |event| event[:kind] == :branch_linked }

    expect(branch).to include(occurred_at: Time.zone.parse('2026-09-05T17:00:00Z'))
    expect(branch[:payload]).to eq('action' => { 'id' => 8001, 'entity_type' => 'branch', 'action' => 'push' })
  end

  it 'reads the story\'s own actions whether its ID comes as a number or a string' do
    expect(events('history_7001', story_id: '7001').pluck(:kind)).to include(:opened, :status_changed)
  end

  it 'gives two links in one entry an event each' do
    history = [{ 'id' => 'z-1', 'changed_at' => '2026-09-10T15:00:00Z',
                 'actions' => [{ 'id' => 8001, 'entity_type' => 'commit', 'action' => 'create' },
                               { 'id' => 8002, 'entity_type' => 'commit', 'action' => 'create' }] }]

    ids = described_class.new(story_id: 7001, workflow: workflow, history: history).events.pluck(:external_id)

    expect(ids.uniq.size).to be(2)
  end

  # A pull request is linked once, however often it changes afterward
  it 'gives a linked pull request one ID, whichever entry mentions it' do
    later = { 'id' => 'p-9', 'changed_at' => '2026-09-20T15:00:00Z',
              'actions' => [{ 'id' => 8101, 'entity_type' => 'pull-request', 'action' => 'update' }] }
    history = shortcut_fixture('history_7001') + [later]

    ids = described_class.new(story_id: 7001, workflow: workflow, history: history).events
                         .select { |event| event[:kind] == :pull_request_linked }.pluck(:external_id)

    expect(ids.uniq.size).to be(1)
  end

  # A link is stored at its first appearance, so that has to be its earliest
  it 'reads entries in time order, whatever order they arrive in' do
    later = { 'id' => 'p-9', 'changed_at' => '2026-09-20T15:00:00Z',
              'actions' => [{ 'id' => 8101, 'entity_type' => 'pull-request', 'action' => 'update' }] }
    newest_first = (shortcut_fixture('history_7001') + [later]).reverse

    linked = described_class.new(story_id: 7001, workflow: workflow, history: newest_first).events
                            .find { |event| event[:kind] == :pull_request_linked }

    expect(linked[:occurred_at]).to eq(Time.zone.parse('2026-09-08T15:00:00Z'))
  end

  # An entry without a time cannot be placed among the others
  it 'skips an entry that gives no time' do
    history = shortcut_fixture('history_7001') + [{ 'id' => 'q-1', 'actions' => [
      { 'id' => 8301, 'entity_type' => 'commit', 'action' => 'create' }
    ] }]

    expect(described_class.new(story_id: 7001, workflow: workflow, history: history).events.size).to be(7)
  end

  it 'reads an entry without actions as no events' do
    history = [{ 'id' => 'n-1', 'changed_at' => '2026-09-10T15:00:00Z', 'references' => [] }]

    expect(described_class.new(story_id: 7001, workflow: workflow, history: history).events).to be_empty
  end

  it 'ignores what an entry records about other stories' do
    history = [{ 'id' => 'y-1', 'changed_at' => '2026-09-10T15:00:00Z',
                 'actions' => [{ 'id' => 7999, 'entity_type' => 'story', 'action' => 'update',
                                 'changes' => { 'workflow_state_id' => { 'old' => 101, 'new' => 103 } } }] }]

    expect(described_class.new(story_id: 7001, workflow: workflow, history: history).events).to be_empty
  end
end
