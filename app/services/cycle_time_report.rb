# A tracker's finished stories measured by one clock: committed to done, or
# started to done, in calendar time. A story with no start for the clock is
# left out of it and counted in the coverage.
class CycleTimeReport
  CLOCKS = %w[committed started].freeze

  attr_reader :clock

  def initialize(tracker, clock:)
    @tracker = tracker
    @clock = clock.to_s
    raise ArgumentError, "unknown clock: #{clock}" unless CLOCKS.include?(@clock)
  end

  def stories
    @stories ||= finished.where.not(start_column => nil).order(:done_at, :id).to_a
  end

  def days(story)
    (story.done_at - story.public_send(start_column)) / 1.day
  end

  def median_days
    percentile(50)
  end

  def p85_days
    percentile(85)
  end

  # How many of the clock's stories took their start from the tracker's
  # chosen trigger, how many from a fallback, and how many had no start.
  def coverage
    trigger = @tracker.triggers.fetch(@clock.to_sym).first.to_s
    sources = stories.map { |story| story.public_send(source_column) }
    {
      trigger: sources.count(trigger),
      fallback: sources.count { |source| source != trigger },
      missing: finished.where(start_column => nil).count
    }
  end

  private

  def finished
    @tracker.stories.where(gone: false).where.not(done_at: nil)
  end

  def start_column
    :"#{@clock}_at"
  end

  def source_column
    :"#{@clock}_source"
  end

  # The nearest-rank method: the smallest value at least p percent of the
  # values are no greater than.
  def percentile(percent)
    sorted = stories.map { |story| days(story) }.sort
    return if sorted.empty?

    sorted[(percent / 100.0 * sorted.size).ceil - 1]
  end
end
