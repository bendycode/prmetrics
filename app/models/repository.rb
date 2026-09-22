class Repository < ApplicationRecord
  has_many :pull_requests, dependent: :destroy
  has_many :weeks, dependent: :destroy
  has_many :repository_grants, dependent: :delete_all

  scope :visible_to, ->(user) { user.admin? ? all : where(id: user.repository_grants.select(:repository_id)) }

  validates :name, presence: true, uniqueness: true
  validates :url, presence: true, uniqueness: true

  validate :valid_github_repository_format

  before_validation :normalize_github_url

  # A promotion deploys work rather than developing it: it merges into a
  # branch the default branch itself is merged into, such as main into
  # production. Keying on the target branch rather than the head keeps
  # promotions made before a rename of the default branch. Returns the pull
  # requests whose flag changed.
  def refresh_promotions!
    targets = promotion_targets
    changed = pull_requests.where(promotion: false, base_ref: targets).to_a +
              pull_requests.where(promotion: true).where.not(base_ref: targets).to_a
    changed.each { |pull_request| pull_request.update!(promotion: !pull_request.promotion) }
  end

  private

  def promotion_targets
    return [] if default_branch.blank?

    pull_requests.where(head_ref: default_branch).where.not(base_ref: default_branch).distinct.pluck(:base_ref)
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
