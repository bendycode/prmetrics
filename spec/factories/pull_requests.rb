FactoryBot.define do
  factory :pull_request do
    repository
    sequence(:number) { |n| n }
    sequence(:title) { |n| "Pull Request #{n}" }
    state { "open" }
    draft { false }
    gh_created_at { Time.current }
    gh_updated_at { Time.now }
  end
end
