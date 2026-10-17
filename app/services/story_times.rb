# The committed, started, and done times of a story, derived from its events.
# For committed and started the triggers list event kinds in order of
# preference; the earliest matching event wins whichever kind it is, and its
# kind is recorded as the source of the time.
class StoryTimes
  ABANDONED = %w[not_planned duplicate].freeze

  attr_reader :committed_at, :committed_source, :started_at, :started_source, :done_at

  def initialize(events:, triggers:, state_reason:)
    @events = events.sort_by(&:occurred_at)
    @done_at = done_time(state_reason)
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
  def done_time(state_reason)
    return if ABANDONED.include?(state_reason)

    last = @events.reverse.find { |event| %w[closed reopened].include?(event.kind.to_s) }
    last.occurred_at if last&.kind.to_s == 'closed'
  end

  def earliest(kinds, before: nil)
    found = @events.find do |event|
      kinds.include?(event.kind.to_sym) && (before.nil? || event.occurred_at <= before)
    end
    found ? [found.occurred_at, found.kind.to_sym] : [nil, nil]
  end
end
