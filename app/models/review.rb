class Review < ApplicationRecord
  belongs_to :pull_request

  validates :state, presence: true
end
