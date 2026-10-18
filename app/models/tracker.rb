# Where a project's stories live. A tracker covers one or more repositories,
# since one workspace can serve several; a GitHub issues tracker reads the
# issues of its source repository.
class Tracker < ApplicationRecord
  # What differs between kinds of tracker: the service that reads its stories
  # in, what it calls a story, where its stories' own pages live, and the
  # events its times are measured from. For committed and started, the first
  # trigger is the one the kind is measured by and the rest are fallbacks
  # meaning the same. Done is the last close with no reopen after it.
  KINDS = {
    'github_issues' => {
      sync: GithubIssueSync,
      story_noun: 'issue',
      story_url_prefix: 'https://github.com/',
      triggers: {
        committed: [StoryTrigger[:opened]],
        started: [StoryTrigger[:assigned], StoryTrigger[:commit_referenced], StoryTrigger[:pull_request_linked]],
        done: { close: [StoryTrigger[:closed]], reopen: [StoryTrigger[:reopened]] }
      }
    },
    'shortcut' => {
      story_noun: 'story',
      story_url_prefix: 'https://app.shortcut.com/'
    }
  }.freeze

  belongs_to :source_repository, class_name: 'Repository', optional: true, inverse_of: :issue_tracker
  has_many :repositories, dependent: :nullify
  has_many :stories, dependent: :destroy

  enum :kind, { github_issues: 0, shortcut: 1 }
  store_accessor :config, :key_prefix, :workflow_id
  encrypts :api_token

  # A user sees a tracker when they were granted any of the repositories it
  # covers, so a tracker shared by several repositories shows every story in
  # it to each of their users.
  scope :visible_to, lambda { |user|
    user.admin? ? all : where(id: Repository.visible_to(user).select(:tracker_id))
  }

  validates :kind, presence: true
  validates :source_repository, presence: true, if: :github_issues?
  validates :source_repository, absence: true, if: :shortcut?
  validates :api_token, :workflow_id, presence: true, if: :shortcut?
  validates :key_prefix, format: { with: /\A[A-Z][A-Z0-9]*\z/ },
                         allow_blank: true
  validates :source_repository_id, uniqueness: true, allow_nil: true

  def triggers
    kind_details[:triggers]
  end

  def sync!
    kind_details[:sync].new(self).sync!
  end

  def story_noun
    kind_details[:story_noun]
  end

  # Whether a stored story URL is a page on this kind's own site, which is
  # all the Cycle Time page will link to.
  def story_url?(url)
    url.to_s.start_with?(kind_details[:story_url_prefix])
  end

  # The project's own name for a story, PRJ-NNN where it declares a key
  # prefix, and GitHub's #NNN otherwise.
  def story_key(number)
    key_prefix.present? ? "#{key_prefix}-#{number}" : "##{number}"
  end

  private

  def kind_details
    KINDS.fetch(kind)
  end
end
