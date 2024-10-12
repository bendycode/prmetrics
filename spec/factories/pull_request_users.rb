FactoryBot.define do
  factory :pull_request_user do
    pull_request
    user
    role { "author" }
  end
end
