class Repository < ApplicationRecord
  has_many :pull_requests, dependent: :destroy
  has_many :weeks, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :url, presence: true, uniqueness: true
  
  validate :valid_github_repository_format
  
  before_validation :normalize_github_url
  
  private
  
  def valid_github_repository_format
    return if name.blank?
    
    unless name.match?(/\A[\w\-\.]+\/[\w\-\.]+\z/)
      errors.add(:name, "must be in format 'owner/repository'")
    end
  end
  
  def normalize_github_url
    return if name.blank?
    
    # Auto-generate URL from name if not provided
    if url.blank? && name.present?
      self.url = "https://github.com/#{name}"
    end
    
    # Ensure URL ends without .git
    self.url = url.chomp('.git') if url.present?
  end
end
