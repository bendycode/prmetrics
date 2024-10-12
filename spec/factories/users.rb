FactoryBot.define do
  factory :user do
    sequence(:username) { |n| "user_#{n}" }
    sequence(:name) { |n| "User #{n}" }
    sequence(:email) { |n| "user_#{n}@example.com" }
  end
end
