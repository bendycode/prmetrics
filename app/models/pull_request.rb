class PullRequest < ApplicationRecord
  belongs_to :repository
  has_many :reviews
  has_many :pull_request_users
  has_many :users, through: :pull_request_users

  validates :number, presence: true
  validates :title, presence: true
  validates :state, presence: true

  def time_to_first_review
    first_review = reviews.order(:gh_submitted_at).first
    return nil unless first_review && ready_for_review_at

    first_review.gh_submitted_at - ready_for_review_at
  end
end
