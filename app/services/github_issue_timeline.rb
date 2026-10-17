# A GitHub issue's timeline as story events: the event kinds cycle time is
# measured from, each with an ID that stays the same on every read so the
# event is stored once.
class GithubIssueTimeline
  KINDS = {
    'assigned' => :assigned,
    'referenced' => :commit_referenced,
    'cross-referenced' => :pull_request_linked,
    'closed' => :closed,
    'reopened' => :reopened
  }.freeze

  def initialize(repo_name:, issue:, timeline:)
    @repo_name = repo_name
    @issue = issue.to_h.deep_stringify_keys
    @timeline = timeline.map { |event| event.to_h.deep_stringify_keys }
  end

  def events
    [opened] + @timeline.filter_map { |event| story_event(event) }
  end

  private

  # GitHub's timeline has no event for the issue being opened.
  def opened
    { external_id: 'opened', kind: :opened, occurred_at: time(@issue['created_at']), payload: {} }
  end

  def story_event(event)
    kind = KINDS[event['event']]
    return if kind.nil?
    return if kind == :pull_request_linked && !same_repository_pull_request?(event)

    { external_id: external_id(event, kind), kind: kind, occurred_at: time(event['created_at']), payload: event }
  end

  # A cross-reference comes from anything that mentioned the issue; only a
  # pull request in the issue's own repository is work on it.
  def same_repository_pull_request?(event)
    source = event.dig('source', 'issue') || {}
    source['pull_request'].present? && source.dig('repository', 'full_name') == @repo_name
  end

  # GitHub gives cross-references no ID, so one is built from what the event
  # is: its kind, the pull request it came from, and when.
  def external_id(event, kind)
    return event['id'].to_s if event['id']

    [kind, event.dig('source', 'issue', 'number'), time(event['created_at']).iso8601].join(':')
  end

  def time(value)
    Time.zone.parse(value.to_s)
  end
end
