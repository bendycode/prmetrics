# One kind of story event a tracker measures a time from, optionally only
# when the event's payload holds the given values, as a status change counts
# as a start only when it moves into a started state.
StoryTrigger = Data.define(:kind, :conditions) do
  def self.[](kind, conditions = {})
    new(kind: kind, conditions: conditions)
  end

  def initialize(kind:, conditions: {})
    raise ArgumentError, "Stories record no #{kind} events" unless StoryEvent::KINDS.key?(kind.to_sym)

    super(kind: kind.to_sym, conditions: conditions.deep_stringify_keys.freeze)
  end

  def matches?(event)
    event.kind.to_sym == kind && contains?(event.payload, conditions)
  end

  private

  def contains?(actual, expected)
    expected.all? do |key, value|
      value.is_a?(Hash) ? actual[key].is_a?(Hash) && contains?(actual[key], value) : actual[key] == value
    end
  end
end
