FactoryBot.define do
  factory :pull_request_user do
    role { "MyString" }
    pull_request { nil }
    user { nil }
  end
end
