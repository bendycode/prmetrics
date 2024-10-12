class PullRequest < ApplicationRecord
  belongs_to :repository
  has_many :reviews
  has_many :pull_request_users
  has_many :users, through: :pull_request_users

  validates :number, presence: true
  validates :title, presence: true
  validates :state, presence: true
end
