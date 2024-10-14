class Repository < ApplicationRecord
  has_many :pull_requests
  has_many :weeks, dependent: :destroy

  validates :name, presence: true
  validates :url, presence: true
end
