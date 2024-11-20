class GithubUser < ApplicationRecord
  has_many :authored_pull_requests, class_name: 'PullRequest', foreign_key: 'author_id'
  validates :username, :github_id, presence: true
  validates :github_id, uniqueness: true
end
