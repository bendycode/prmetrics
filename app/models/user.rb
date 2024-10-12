class User < ApplicationRecord
  has_many :pull_request_users
  has_many :pull_requests, through: :pull_request_users

  validates :username, presence: true
end
