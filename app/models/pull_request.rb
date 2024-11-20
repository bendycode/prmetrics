class PullRequest < ApplicationRecord
  belongs_to :repository
  belongs_to :author, class_name: 'GithubUser'
  belongs_to :ready_for_review_week, class_name: 'Week', optional: true
  belongs_to :first_review_week, class_name: 'Week', optional: true
  belongs_to :merged_week, class_name: 'Week', optional: true
  belongs_to :closed_week, class_name: 'Week', optional: true

  has_many :reviews
  has_many :pull_request_users, dependent: :destroy
  has_many :users, through: :pull_request_users

  validates :number, presence: true
  validates :title, presence: true
  validates :state, presence: true

  def time_to_first_review
    first_review = reviews
      .where('submitted_at > ?', ready_for_review_at)
      .order(:submitted_at)
      .first
    return nil unless first_review && ready_for_review_at

    first_review.submitted_at - ready_for_review_at
  end

  def update_week_associations
    self.ready_for_review_week = Week.find_by_date(ready_for_review_at)

    # Find first valid review after ready_for_review_at
    first_valid_review = reviews
      .where('submitted_at > ?', ready_for_review_at)
      .order(:submitted_at)
      .first

    self.first_review_week = Week.find_by_date(first_valid_review&.submitted_at)
    self.merged_week = Week.find_by_date(gh_merged_at)
    self.closed_week = Week.find_by_date(gh_closed_at)
    save
  end
end
