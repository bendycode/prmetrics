class Review < ApplicationRecord
  belongs_to :pull_request
  belongs_to :author, class_name: 'Contributor'

  # Turn on once values are captured for existing review records
  # validates :author, presence: true
  validates :state, presence: true

  scope :ordered, -> { order(submitted_at: :desc) }
end
