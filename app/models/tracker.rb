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
    # Committed when a story reaches the workflow's commitment, its last
    # unstarted state, or is created at or past it; started when it reaches a
    # started state, or is created in one,
    # with code linked to it as the fallbacks; done on a move into a done
    # state, and undone by a move back out of one.
    'shortcut' => {
      sync: ShortcutStorySync,
      story_noun: 'story',
      story_url_prefix: 'https://app.shortcut.com/',
      triggers: {
        committed: [StoryTrigger[:status_changed, 'to' => { 'committed' => true }],
                    StoryTrigger[:opened, 'state' => { 'committed' => true }]],
        started: [StoryTrigger[:status_changed, 'to' => { 'type' => 'started' }],
                  StoryTrigger[:opened, 'state' => { 'type' => 'started' }],
                  StoryTrigger[:branch_linked], StoryTrigger[:commit_referenced], StoryTrigger[:pull_request_linked]],
        done: { close: [StoryTrigger[:status_changed, 'to' => { 'type' => 'done' }]],
                reopen: [StoryTrigger[:status_changed, 'from' => { 'type' => 'done' }]] }
      }
    }
  }.freeze

  belongs_to :source_repository, class_name: 'Repository', optional: true, inverse_of: :issue_tracker
  has_many :repositories, dependent: :nullify
  has_many :stories, dependent: :destroy

  enum :kind, { github_issues: 0, shortcut: 1 }
  store_accessor :config, :key_prefix, :workflow_id
  encrypts :api_token

  scope :reading_workflow, ->(workflow_id) { shortcut.where("config->>'workflow_id' = ?", workflow_id.to_s) }

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
  validates :workflow_id, format: { with: /\A[1-9]\d*\z/, allow_blank: true }, if: :shortcut?
  validate :workflow_read_once, if: :shortcut?
  validates :key_prefix, format: { with: /\A[A-Z][A-Z0-9]*\z/ },
                         allow_blank: true
  validates :source_repository_id, uniqueness: true, allow_nil: true

  # Whether a token can be written: Active Record encryption raises on a
  # token, and only on one, when its keys are not set.
  def self.token_encryption_configured?
    ActiveRecord::Encryption.config.primary_key
    ActiveRecord::Encryption.config.key_derivation_salt
    true
  rescue ActiveRecord::Encryption::Errors::Configuration
    false
  end

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

  # The project's own name for a story: Shortcut's sc-NNN for a Shortcut
  # story, PRJ-NNN where a GitHub tracker declares a key prefix, and GitHub's
  # #NNN otherwise.
  def story_key(number)
    return "sc-#{number}" if shortcut?

    key_prefix.present? ? "#{key_prefix}-#{number}" : "##{number}"
  end

  private

  # Two trackers reading one workflow would each store, and count, every story
  def workflow_read_once
    return if workflow_id.blank? || !Tracker.reading_workflow(workflow_id).where.not(id: id).exists?

    errors.add(:workflow_id, 'is already read by another Shortcut tracker')
  end

  def kind_details
    KINDS.fetch(kind)
  end
end
