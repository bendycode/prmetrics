# A piece of work in a tracker, such as a GitHub issue, with the times its
# cycle is measured between. The times are derived from its events.
class Story < ApplicationRecord
  belongs_to :tracker
  has_many :events, -> { order(:id) }, class_name: 'StoryEvent', dependent: :delete_all, inverse_of: :story

  enum :committed_source, StoryEvent::KINDS, prefix: :committed_by
  enum :started_source, StoryEvent::KINDS, prefix: :started_by

  validates :key, :title, :url, :source_created_at, :source_updated_at, :listed_at, presence: true
  validates :state, inclusion: { in: %w[open closed] }
  validates :external_id, uniqueness: { scope: :tracker_id }

  # Done, and still on GitHub: the stories cycle time is measured over
  scope :finished, -> { where(gone: false).where.not(done_at: nil) }

  # A story listed at least a minute after its stored update, which GitHub's
  # whole-second timestamps and clock drift between it and this app could
  # otherwise hide behind.
  scope :listed_after_last_update, -> { where("listed_at >= source_updated_at + interval '1 minute'") }

  # Derives the committed, started, and done times from the story's events
  # and saves them, with the kind of event the committed and started times
  # came from.
  def measure(triggers)
    times = StoryTimes.new(events: events, triggers: triggers, state_reason: state_reason)
    update!(
      committed_at: times.committed_at, committed_source: times.committed_source,
      started_at: times.started_at, started_source: times.started_source,
      done_at: times.done_at
    )
  end

  # Stores the events not stored already. Each read of a timeline returns
  # every event it has seen before, keyed by the same IDs.
  def record_events(attributes)
    unique = attributes.uniq { |event| event[:external_id] }
    stored = events.where(external_id: unique.pluck(:external_id)).pluck(:external_id).to_set
    unique.reject { |event| stored.include?(event[:external_id]) }.each { |event| events.create!(event) }
  end
end
