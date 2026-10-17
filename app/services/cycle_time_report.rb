# A tracker's finished stories measured by one clock: committed to done, or
# started to done, in elapsed time, weekends included. A story with no start
# for the clock is left out of it and counted in the coverage.
class CycleTimeReport
  CLOCKS = %w[committed started].freeze
  DEFAULT_CLOCK = CLOCKS.first

  attr_reader :clock

  def initialize(tracker, clock:)
    @tracker = tracker
    @clock = clock.to_s
    raise ArgumentError, "unknown clock: #{clock}" unless CLOCKS.include?(@clock)
  end

  def stories
    @stories ||= @tracker.stories.finished.where.not(start_column => nil).order(:done_at, :id).to_a
  end

  # Whether any story is finished at all, whether or not it has a start for
  # this clock
  def any_finished?
    @tracker.stories.finished.exists?
  end

  def days(story)
    (story.done_at - story.public_send(start_column)).seconds.in_days
  end

  def median_days
    percentile(50)
  end

  def p85_days
    percentile(85)
  end

  # The event kind the tracker measures this clock from by choice; the rest
  # of its triggers are fallbacks.
  def trigger
    @tracker.triggers.fetch(@clock.to_sym).first
  end

  # How many of the clock's stories took their start from the tracker's
  # chosen trigger, how many from a fallback, and how many had no start.
  def coverage
    chosen = trigger.to_s
    sources = stories.map { |story| story.public_send(source_column) }
    {
      trigger: sources.count(chosen),
      fallback: sources.count { |source| source != chosen },
      missing: @tracker.stories.finished.where(start_column => nil).count
    }
  end

  private

  def start_column
    :"#{@clock}_at"
  end

  def source_column
    :"#{@clock}_source"
  end

  # The nearest-rank method: the smallest value at least p percent of the
  # values are no greater than.
  def percentile(percent)
    return if sorted_days.empty?

    sorted_days[(percent / 100.0 * sorted_days.size).ceil - 1]
  end

  def sorted_days
    @sorted_days ||= stories.map { |story| days(story) }.sort
  end
end
