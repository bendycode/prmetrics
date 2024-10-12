class Repository < ApplicationRecord
  has_many :pull_requests

  validates :name, presence: true
  validates :url, presence: true
end
