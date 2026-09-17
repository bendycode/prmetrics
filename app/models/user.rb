class User < ApplicationRecord
  devise :invitable, :database_authenticatable,
         :recoverable, :rememberable, :validatable, :trackable

  enum :role, { regular_user: 0, admin: 1 }, default: :regular_user

  has_many :repository_grants, dependent: :destroy
  has_many :granted_repositories, through: :repository_grants, source: :repository

  validates :role, presence: true

  def self.last_admin?(user)
    user&.admin? && admin.count <= 1
  end
end
