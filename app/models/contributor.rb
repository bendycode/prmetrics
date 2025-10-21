class Contributor < ApplicationRecord
  # Pull request associations
  has_many :authored_pull_requests, class_name: 'PullRequest', foreign_key: 'author_id', dependent: :nullify
  has_many :pull_request_users, foreign_key: 'user_id', dependent: :destroy
  has_many :participated_pull_requests, through: :pull_request_users, source: :pull_request

  # Review associations
  has_many :reviews, foreign_key: 'author_id', dependent: :destroy

  # Validations
  validates :username, presence: true, uniqueness: true
  validates :github_id, presence: true, uniqueness: true

  # Scopes
  scope :with_github_data, -> { where.not(github_id: nil).where.not("github_id LIKE 'user_%'") }
  scope :authors, -> { joins(:authored_pull_requests).distinct }
  scope :reviewers, -> { joins(:reviews).distinct }

  # Find or create contributor using full GitHub API data
  def self.find_or_create_from_github(github_user)
    return nil unless github_user

    find_or_create_by(github_id: github_user.id.to_s) do |contributor|
      contributor.username = github_user.login
      contributor.name = github_user.name
      contributor.avatar_url = github_user.avatar_url
      contributor.email = github_user.email
    end
  end

  # Find or create contributor with minimal data (for backward compatibility)
  def self.find_or_create_from_username(username, additional_attrs = {})
    return nil unless username

    # First try to find by username
    contributor = find_by(username: username)
    return contributor if contributor

    # Create with a placeholder github_id if not provided
    create!(
      username: username,
      github_id: additional_attrs[:github_id] || "placeholder_#{SecureRandom.hex(8)}",
      name: additional_attrs[:name],
      email: additional_attrs[:email]
    )
  end

  # Helper to get display name (falls back to username if name is blank)
  def display_name
    name.presence || username
  end

  # Check if this is a real GitHub user vs placeholder
  def has_github_data?
    github_id.present? && !github_id.starts_with?('placeholder_') && !github_id.starts_with?('user_')
  end

  # Get all pull requests this contributor is involved with (authored or participated)
  def all_pull_requests
    PullRequest.left_joins(:pull_request_users)
               .where('pull_requests.author_id = ? OR pull_request_users.user_id = ?', id, id)
               .distinct
  end
end