# The committed, started, and done times of a story, derived from its events.
# For committed and started the triggers list StoryTriggers in order of
# preference; the earliest matching event wins whichever trigger it matched,
# and its kind is recorded as the source of the time. The done rules name the
# events that close a story and those that reopen it.
class StoryTimes
  ABANDONED = %w[not_planned duplicate].freeze

  attr_reader :committed_at, :committed_source, :started_at, :started_source, :done_at

  def initialize(events:, triggers:, state_reason:)
    # GitHub's times are whole seconds, so events in the same second keep the
    # order they were given in: Ruby's sort does not promise to.
    @events = events.each_with_index.sort_by { |event, index| [event.occurred_at, index] }.map(&:first)
    @done_at = done_time(triggers[:done], state_reason)
    @started_at, @started_source = earliest(triggers[:started], before: @done_at)
    @committed_at, @committed_source = earliest(triggers[:committed])
    return unless @started_at && (@committed_at.nil? || @committed_at > @started_at)

    # Work can't start before it was committed to, as when a branch is pushed
    # before its issue is filed.
    @committed_at = @started_at
    @committed_source = @started_source
  end

  private

  # Done is the last close with no reopen after it. GitHub records why an
  # issue was closed on the issue rather than on the close event, so only the
  # issue's current reason can say the close abandoned the work. Issues closed
  # before GitHub recorded reasons have none, and count as done.
  def done_time(rules, state_reason)
    return if ABANDONED.include?(state_reason)

    last = @events.reverse_each.find do |event|
      matches_any?(rules[:close], event) || matches_any?(rules[:reopen], event)
    end
    last.occurred_at if last && matches_any?(rules[:close], last)
  end

  def earliest(triggers, before: nil)
    found = @events.find do |event|
      matches_any?(triggers, event) && (before.nil? || event.occurred_at <= before)
    end
    found ? [found.occurred_at, found.kind.to_sym] : [nil, nil]
  end

  def matches_any?(triggers, event)
    triggers.any? { |trigger| trigger.matches?(event) }
  end
end
