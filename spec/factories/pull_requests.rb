FactoryBot.define do
  factory :pull_request do
    repository
    sequence(:number) { |n| n }
    sequence(:title) { |n| "Pull Request #{n}" }
    state { "open" }
    draft { false }
    created_at { Time.current }
    updated_at { Time.current }
  end
end
