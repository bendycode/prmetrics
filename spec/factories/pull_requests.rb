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
  end
end
