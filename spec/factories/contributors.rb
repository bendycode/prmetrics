FactoryBot.define do
  factory :contributor do
    sequence(:username) { |n| "contributor_#{n}" }
    sequence(:name) { |n| "Contributor #{n}" }
    sequence(:email) { |n| "contributor_#{n}@example.com" }
    sequence(:github_id) { |n| "github_#{n}" }
    sequence(:avatar_url) { |n| "https://github.com/avatars/#{n}.png" }

    # Factory for GitHub users (PR authors with full GitHub data)
    factory :github_user, aliases: [:author] do
      sequence(:username) { |n| "github_user#{n}" }
      sequence(:github_id) { |n| n.to_s }
      sequence(:avatar_url) { |n| "https://avatars.githubusercontent.com/u/#{n}" }
      email { nil } # GitHub users might not have email
    end

    # Factory for reviewers
    factory :reviewer do
      sequence(:username) { |n| "reviewer#{n}" }
      sequence(:github_id) { |n| "reviewer_#{n}" }
      sequence(:email) { |n| "reviewer#{n}@example.com" }
    end

    # Factory for contributors with placeholder github_id
    factory :legacy_user do
      sequence(:username) { |n| "legacy_user#{n}" }
      sequence(:github_id) { |n| "placeholder_#{SecureRandom.hex(4)}" }
      sequence(:email) { |n| "legacy#{n}@example.com" }
    end
  end
end