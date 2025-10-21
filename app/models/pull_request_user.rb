class PullRequestUser < ApplicationRecord
  belongs_to :pull_request
  belongs_to :user, class_name: 'Contributor'

  validates :role, presence: true
  validates :user_id, uniqueness: { scope: %i[pull_request_id role] }
end
