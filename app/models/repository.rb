class Repository < ApplicationRecord
  has_many :pull_requests, dependent: :destroy
  has_many :weeks, dependent: :destroy
  has_many :repository_grants, dependent: :delete_all

  scope :visible_to, ->(user) { user.admin? ? all : where(id: user.repository_grants.select(:repository_id)) }

  validates :name, presence: true, uniqueness: true
  validates :url, presence: true, uniqueness: true

  validate :valid_github_repository_format

  before_validation :normalize_github_url

  def development_pull_requests
    pull_requests.development
  end

  # A promotion deploys work rather than developing it: it merges into one of
  # the repository's deploy branches, such as main into production. Keying on
  # the target branch rather than the head keeps promotions made before a
  # rename of the default branch. Returns the pull requests whose flag
  # changed, in one transaction so a failure leaves none of them flipped.
  def refresh_promotions!
    targets = deploy_branches
    changed = pull_requests.development.into_branch(targets).to_a +
              pull_requests.promotions.where.not(base_ref: targets).to_a

    transaction { changed.each { |pull_request| pull_request.update!(promotion: !pull_request.promotion) } }
    changed
  end

  private

  # A deploy branch receives the default branch's own merged pull requests and
  # never merges back into it. That second half is what tells a deploy branch
  # from a long-lived feature branch someone merged the default branch into to
  # catch it up: the feature branch merges back, a deploy branch does not.
  def deploy_branches
    return [] if default_branch.blank?

    deploys = pull_requests.merged.from_branch(default_branch).where(head_repository: name)
    candidates = deploys.where.not(base_ref: default_branch).distinct.pluck(:base_ref)
    candidates - branches_merged_into_default
  end

  # Our own branches only, on this side too: a fork's branch named after a
  # deploy branch would otherwise disqualify that branch and unflag every
  # promotion in the repository.
  def branches_merged_into_default
    pull_requests.merged.into_branch(default_branch).where(head_repository: name)
                 .where.not(head_ref: nil).distinct.pluck(:head_ref)
  end

  def valid_github_repository_format
    return if name.blank?

    return if name.match?(%r{\A[\w\-.]+/[\w\-.]+\z})

    errors.add(:name, "must be in format 'owner/repository'")
  end

  def normalize_github_url
    return if name.blank?

    # Auto-generate URL from name if not provided
    self.url = "https://github.com/#{name}" if url.blank? && name.present?

    # Ensure URL ends without .git
    self.url = url.chomp('.git') if url.present?
  end
end
