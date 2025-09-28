FactoryBot.define do
  factory :review do
    pull_request
    state { "APPROVED" }
    submitted_at { Time.current }
    author { create :user }
  end
end
