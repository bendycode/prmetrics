FactoryBot.define do
  factory :github_user do
    sequence(:username) { |n| "user#{n}" }
    sequence(:github_id) { |n| n.to_s }
    sequence(:name) { |n| "User #{n}" }
    sequence(:avatar_url) { |n| "https://github.com/avatars/#{n}.png" }
  end
end
