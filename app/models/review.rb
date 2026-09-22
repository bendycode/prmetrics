class Review < ApplicationRecord
  belongs_to :pull_request
  belongs_to :author, class_name: 'Contributor'

  # Turn on once values are captured for existing review records
  # validates :author, presence: true
  validates :state, presence: true
  validates :submitted_at, presence: true
  validates :submitted_at, uniqueness: {
    scope: %i[pull_request_id author_id state],
    message: 'review already exists for this pull request, author, and state combination'
  }

  after_destroy :update_pull_request_review_weeks, unless: :skip_week_association_update
  after_save :update_pull_request_review_weeks, unless: :skip_week_association_update

  scope :ordered, -> { order(submitted_at: :desc) }
  scope :approved, -> { where(state: 'APPROVED') }
  scope :by_people, -> { joins(:author).where(contributors: { bot: false }) }

  def skip_week_association_update
    @skip_week_association_update || false
  end

  def skip_week_association_update!
    @skip_week_association_update = true
  end

  private

  # A review changes both the week a pull request was first reviewed in and
  # the week it was approved in, so one method keeps the pair in step.
  def update_pull_request_review_weeks
    return unless pull_request&.ready_for_review_at

    weeks = pull_request.repository.weeks
    # Repository-scoped lookups prevent cross-repository associations
    new_weeks = { first_review_week_id: weeks.find_by_date(pull_request.valid_first_review&.submitted_at)&.id,
                  first_approval_week_id: weeks.find_by_date(pull_request.approved_at)&.id }

    moved = new_weeks.reject { |column, week_id| pull_request[column] == week_id }
    pull_request.update_columns(moved) if moved.any?
  end
end
