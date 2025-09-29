FactoryBot.define do
  factory :review do
    pull_request
    state { "APPROVED" }
    submitted_at { Time.current }
    author { association :contributor }

    trait :commented do
      state { "COMMENTED" }
    end

    trait :changes_requested do
      state { "CHANGES_REQUESTED" }
    end
  end
end
