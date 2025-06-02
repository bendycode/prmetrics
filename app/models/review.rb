class Review < ApplicationRecord
  belongs_to :pull_request
  belongs_to :author, class_name: 'Contributor'

  # Turn on once values are captured for existing review records
  # validates :author, presence: true
  validates :state, presence: true
  validates :submitted_at, presence: true
  validates :submitted_at, uniqueness: { 
    scope: [:pull_request_id, :author_id, :state],
    message: "review already exists for this pull request, author, and state combination"
  }

  after_save :update_pull_request_first_review_week, unless: :skip_week_association_update
  after_destroy :update_pull_request_first_review_week, unless: :skip_week_association_update

  scope :ordered, -> { order(submitted_at: :desc) }

  def skip_week_association_update
    @skip_week_association_update || false
  end

  def skip_week_association_update!
    @skip_week_association_update = true
  end

  private

  def update_pull_request_first_review_week
    return unless pull_request&.ready_for_review_at
    
    # Find the first valid review and update the week association
    first_review = pull_request.valid_first_review
    # Use repository-scoped week lookup to prevent cross-repository associations
    new_week = first_review ? pull_request.repository.weeks.find_by_date(first_review.submitted_at) : nil
    
    if pull_request.first_review_week != new_week
      pull_request.update_column(:first_review_week_id, new_week&.id)
    end
  end
end
