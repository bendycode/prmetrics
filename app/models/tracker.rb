# Where a project's stories live. A tracker covers one or more repositories,
# since one workspace can serve several; a GitHub issues tracker reads the
# issues of its source repository.
class Tracker < ApplicationRecord
  belongs_to :source_repository, class_name: 'Repository', optional: true, inverse_of: :issue_tracker
  has_many :repositories, dependent: :nullify
  has_many :stories, dependent: :destroy

  enum :kind, { github_issues: 0 }

  validates :source_repository, presence: true, if: :github_issues?
  validates :source_repository_id, uniqueness: true, allow_nil: true
end
