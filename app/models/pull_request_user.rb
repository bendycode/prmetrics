class PullRequestUser < ApplicationRecord
  belongs_to :pull_request
  belongs_to :user, class_name: 'Contributor'

  validates :role, presence: true
end
