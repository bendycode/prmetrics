# Where a project's stories live. A tracker covers one or more repositories,
# since one workspace can serve several; a GitHub issues tracker reads the
# issues of its source repository.
class Tracker < ApplicationRecord
  # For committed and started, the first event kind is the trigger this kind
  # of tracker is measured by and the rest are fallbacks meaning the same.
  TRIGGERS = {
    'github_issues' => {
      committed: %i[opened],
      started: %i[assigned commit_referenced pull_request_linked]
    }
  }.freeze

  belongs_to :source_repository, class_name: 'Repository', optional: true, inverse_of: :issue_tracker
  has_many :repositories, dependent: :nullify
  has_many :stories, dependent: :destroy

  enum :kind, { github_issues: 0 }
  store_accessor :config, :key_prefix

  validates :kind, presence: true
  validates :source_repository, presence: true, if: :github_issues?
  validates :key_prefix, format: { with: /\A[A-Z][A-Z0-9]*\z/ },
                         allow_blank: true
  validates :source_repository_id, uniqueness: true, allow_nil: true

  def triggers
    TRIGGERS.fetch(kind)
  end

  # The project's own name for a story, PRJ-NNN where it declares a key
  # prefix, and GitHub's #NNN otherwise.
  def story_key(number)
    key_prefix.present? ? "#{key_prefix}-#{number}" : "##{number}"
  end
end
