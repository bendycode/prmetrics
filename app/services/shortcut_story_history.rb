# A Shortcut story's history as story events: its creation, each move between
# workflow states, and each branch, commit, or pull request linked to it, each
# with an ID that stays the same on every read so the event is stored once.
#
# A state is recorded as the workflow describes it when the history is read,
# with whether it is the workflow's first state, since triggers name a state
# by its type or place rather than its ID.
class ShortcutStoryHistory
  LINK_KINDS = {
    'branch' => :branch_linked,
    'commit' => :commit_referenced,
    'pull-request' => :pull_request_linked
  }.freeze

  def initialize(story_id:, workflow:, history:)
    @story_id = story_id
    @states = workflow.fetch('states').index_by { |state| state['id'] }
    @first_position = @states.values.pluck('position').min
    @history = history
  end

  def events
    @history.flat_map do |entry|
      entry['actions'].filter_map { |action| story_event(entry, action) }
    end
  end

  private

  def story_event(entry, action)
    kind, payload = kind_and_payload(entry, action)
    return unless kind

    { external_id: "#{entry['id']}:#{kind}", kind: kind, occurred_at: Time.zone.parse(entry['changed_at']),
      payload: payload }
  end

  def kind_and_payload(entry, action)
    return [LINK_KINDS[action['entity_type']], { 'action' => action }] if LINK_KINDS.key?(action['entity_type'])
    return unless action['entity_type'] == 'story' && action['id'] == @story_id

    if action['action'] == 'create'
      [:opened, { 'state' => state(action['workflow_state_id'], entry) }]
    elsif (move = action.dig('changes', 'workflow_state_id'))
      [:status_changed, { 'from' => state(move['old'], entry), 'to' => state(move['new'], entry) }]
    end
  end

  # A state another workflow holds, as when the story was moved there, is
  # known only from the entry's own reference to it.
  def state(id, entry)
    known = @states[id] || (entry['references'] || []).find do |reference|
      reference['entity_type'] == 'workflow-state' && reference['id'] == id
    end || {}
    { 'id' => id, 'name' => known['name'], 'type' => known['type'], 'position' => known['position'],
      'first' => known.key?('position') && known['position'] == @first_position }
  end
end
