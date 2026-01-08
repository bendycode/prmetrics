FactoryBot.define do
  factory :pull_request do
    repository
    sequence(:number) { |n| n }
    author { association :github_user }
    sequence(:title) { |n| "Pull Request #{n}" }
    state { 'open' }
    draft { false }
    gh_created_at { Time.current }
    gh_updated_at { Time.now }

    # NOTE: Week associations are automatically set by the model callback
    # No need for explicit after(:create) hook

    trait :draft do
      draft { true }
    end

    trait :approved do
      after(:create) do |pr|
        create(:review, pull_request: pr)
      end
    end

    trait :approved_days_ago do
      transient do
        days_ago { 10 }
      end

      after(:create) do |pr, evaluator|
        create(:review, pull_request: pr, state: 'APPROVED',
                        submitted_at: Time.current - evaluator.days_ago.days)
      end
    end

    # Create a PR approved relative to a specific week's end_date
    # Usage: create(:pull_request, :approved_before_week_end, week: week, days_before_week_end: 10)
    trait :approved_before_week_end do
      transient do
        week { nil }
        days_before_week_end { 10 }
      end

      gh_created_at { Date.new(2023, 12, 1) } # Far in the past to ensure review is valid

      after(:create) do |pr, evaluator|
        raise ArgumentError, 'week is required for :approved_before_week_end trait' unless evaluator.week

        create(:review, pull_request: pr, state: 'APPROVED',
                        submitted_at: evaluator.week.end_date - evaluator.days_before_week_end.days)
      end
    end

    trait :with_comments do
      after(:create) do |pr|
        create(:review, :commented, pull_request: pr)
      end
    end

    # For testing data migrations - sets week associations without triggering callbacks
    trait :with_week_associations do
      transient do
        ready_for_review_week { nil }
        merged_week { nil }
        first_review_week { nil }
        closed_week { nil }
      end

      after(:build, &:skip_week_association_update!)

      after(:create) do |pr, evaluator|
        updates = {}
        updates[:ready_for_review_week_id] = evaluator.ready_for_review_week.id if evaluator.ready_for_review_week
        updates[:merged_week_id] = evaluator.merged_week.id if evaluator.merged_week
        updates[:first_review_week_id] = evaluator.first_review_week.id if evaluator.first_review_week
        updates[:closed_week_id] = evaluator.closed_week.id if evaluator.closed_week
        pr.update_columns(updates) if updates.any?
      end
    end
  end
end
