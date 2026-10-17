# One event in a story's history, in a kind that means the same thing across
# trackers, with the tracker's own record of it kept as the payload so the
# story's times can be derived again without fetching anything.
class StoryEvent < ApplicationRecord
  KINDS = {
    opened: 0,
    assigned: 1,
    commit_referenced: 2,
    pull_request_linked: 3,
    closed: 4,
    reopened: 5
  }.freeze

  belongs_to :story

  enum :kind, KINDS

  validates :external_id, uniqueness: { scope: :story_id }
end
