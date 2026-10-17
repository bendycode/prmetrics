# A piece of work in a tracker, such as a GitHub issue, with the times its
# cycle is measured between. The times are derived from its events.
class Story < ApplicationRecord
  belongs_to :tracker
  has_many :events, class_name: 'StoryEvent', dependent: :delete_all

  enum :committed_source, StoryEvent::KINDS, prefix: :committed_by
  enum :started_source, StoryEvent::KINDS, prefix: :started_by

  validates :external_id, uniqueness: { scope: :tracker_id }

  # Stores the events not stored already. Each read of a timeline returns
  # every event it has seen before, keyed by the same IDs.
  def record_events(attributes)
    stored = events.where(external_id: attributes.pluck(:external_id)).pluck(:external_id)
    attributes.reject { |event| stored.include?(event[:external_id]) }.each { |event| events.create!(event) }
  end
end
