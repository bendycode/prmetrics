FactoryBot.define do
  factory :pull_request do
    repository
    sequence(:number) { |n| n }
    author { association :github_user }
    sequence(:title) { |n| "Pull Request #{n}" }
    state { "open" }
    draft { false }
    gh_created_at { Time.current }
    gh_updated_at { Time.now }

    # Note: Week associations are automatically set by the model callback
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
        create(:review, pull_request: pr,
               submitted_at: evaluator.days_ago.days.ago)
      end
    end

    trait :with_comments do
      after(:create) do |pr|
        create(:review, :commented, pull_request: pr)
      end
    end
  end
end
