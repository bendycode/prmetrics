FactoryBot.define do
  factory :user do
    PASSWORD = "password123".freeze

    sequence(:email) { |n| "user#{n}@example.com" }
    password { PASSWORD }
    password_confirmation { password }
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