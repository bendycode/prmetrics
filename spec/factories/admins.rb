FactoryBot.define do
  factory :admin do
    sequence(:email) { |n| "admin#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    invitation_accepted_at { Time.current }
    
    trait :pending do
      invitation_accepted_at { nil }
      invitation_sent_at { Time.current }
      invitation_token { SecureRandom.hex(10) }
    end
  end
end