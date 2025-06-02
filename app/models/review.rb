class Review < ApplicationRecord
  belongs_to :pull_request
  belongs_to :author, class_name: 'Contributor'

  # Turn on once values are captured for existing review records
  # validates :author, presence: true
  validates :state, presence: true
  validates :submitted_at, presence: true
  validates :submitted_at, uniqueness: { 
    scope: [:pull_request_id, :author_id, :state],
    message: "review already exists for this pull request, author, and state combination"
  }

  scope :ordered, -> { order(submitted_at: :desc) }
end
