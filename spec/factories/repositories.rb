FactoryBot.define do
  factory :repository do
    sequence(:name) { |n| "owner/repository_#{n}" }
    sequence(:url) { |n| "https://github.com/owner/repository_#{n}" }
  end
end
