FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    invitation_accepted_at { Time.current }
    role { :regular_user }

    trait :admin do
      role { :admin }
      sequence(:email) { |n| "admin#{n}@example.com" }
    end

    trait :pending do
      invitation_accepted_at { nil }
      invitation_sent_at { Time.current }
      invitation_token { SecureRandom.hex(10) }
    end
  end
end