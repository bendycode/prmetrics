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
    @story_id = Integer(story_id)
    @states = workflow.fetch('states').index_by { |state| state['id'] }
    @first_position = @states.values.pluck('position').min
    @history = history
  end

  # In time order, so a link's first appearance is its earliest. An entry
  # with no time cannot be placed, and is skipped.
  def events
    timed = @history.each_with_index.filter_map do |entry, index|
      [Time.zone.parse(entry['changed_at']), index, entry] if entry['changed_at'].present?
    end
    timed.sort_by { |time, index, _entry| [time, index] }.flat_map do |time, _index, entry|
      Array(entry['actions']).filter_map { |action| story_event(entry, action, time) }
    end
  end

  private

  def story_event(entry, action, time)
    kind, payload, external_id = event_parts(entry, action)
    return unless kind

    { external_id: external_id, kind: kind, occurred_at: time, payload: payload }
  end

  # A link is keyed on what was linked, so every later action on the same
  # pull request or branch is the event already stored: it was linked once,
  # at its first appearance.
  def event_parts(entry, action)
    if (kind = LINK_KINDS[action['entity_type']])
      return [kind, { 'action' => action }, "#{kind}:#{action['id']}"]
    end
    return unless action['entity_type'] == 'story' && action['id'] == @story_id

    if action['action'] == 'create'
      [:opened, { 'state' => state(action['workflow_state_id'], entry), 'action' => action },
       "#{entry['id']}:opened"]
    elsif (move = action.dig('changes', 'workflow_state_id'))
      [:status_changed, { 'from' => state(move['old'], entry), 'to' => state(move['new'], entry), 'action' => action },
       "#{entry['id']}:status_changed"]
    end
  end

  # A state another workflow holds, as when the story was moved there, is
  # known only from the entry's own reference to it, and is never this
  # workflow's first, whatever position its own workflow gives it.
  def state(id, entry)
    known = @states[id]
    described = known || Array(entry['references']).find do |reference|
      reference['entity_type'] == 'workflow-state' && reference['id'] == id
    end || {}
    { 'id' => id, 'name' => described['name'], 'type' => described['type'], 'position' => known&.dig('position'),
      'first' => known.present? && known['position'] == @first_position }
  end
end
