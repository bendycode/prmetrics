class PullRequestUser < ApplicationRecord
  belongs_to :pull_request
  belongs_to :user

  validates :role, presence: true
end
