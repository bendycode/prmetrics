FactoryBot.define do
  factory :pull_request do
    number { 1 }
    title { "MyString" }
    state { "MyString" }
    draft { false }
    created_at { "2024-10-12 13:59:54" }
    updated_at { "2024-10-12 13:59:54" }
    merged_at { "2024-10-12 13:59:54" }
    closed_at { "2024-10-12 13:59:54" }
    repository { nil }
  end
end
