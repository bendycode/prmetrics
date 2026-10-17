# A piece of work in a tracker, such as a GitHub issue, with the times its
# cycle is measured between. The times are derived from its events.
class Story < ApplicationRecord
  belongs_to :tracker
  has_many :events, -> { order(:id) }, class_name: 'StoryEvent', dependent: :delete_all, inverse_of: :story

  enum :committed_source, StoryEvent::KINDS, prefix: :committed_by
  enum :started_source, StoryEvent::KINDS, prefix: :started_by

  validates :external_id, uniqueness: { scope: :tracker_id }

  # A story listed at least a minute after its stored update, which GitHub's
  # whole-second timestamps and clock drift between it and this app could
  # otherwise hide behind.
  scope :listed_after_last_update, -> { where("listed_at >= gh_updated_at + interval '1 minute'") }

  # Stores the events not stored already. Each read of a timeline returns
  # every event it has seen before, keyed by the same IDs.
  def measure(triggers)
    times = StoryTimes.new(events: events, triggers: triggers, state_reason: state_reason)
    update!(
      committed_at: times.committed_at, committed_source: times.committed_source,
      started_at: times.started_at, started_source: times.started_source,
      done_at: times.done_at
    )
  end

  def record_events(attributes)
    stored = events.where(external_id: attributes.pluck(:external_id)).pluck(:external_id)
    attributes.reject { |event| stored.include?(event[:external_id]) }.each { |event| events.create!(event) }
  end
end
