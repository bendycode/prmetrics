# A piece of work in a tracker, such as a GitHub issue, with the times its
# cycle is measured between. The times are derived from its events.
class Story < ApplicationRecord
  belongs_to :tracker
  has_many :events, class_name: 'StoryEvent', dependent: :delete_all

  enum :committed_source, StoryEvent::KINDS, prefix: :committed_by
  enum :started_source, StoryEvent::KINDS, prefix: :started_by

  validates :external_id, uniqueness: { scope: :tracker_id }
end
