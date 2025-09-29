FactoryBot.define do
  factory :pull_request_user do
    pull_request
    user { association :contributor }
    role { "author" }
  end
end
