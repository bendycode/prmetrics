FactoryBot.define do
  factory :repository do
    sequence(:name) { |n| "repository_#{n}" }
    sequence(:url) { |n| "https://github.com/user/repo_#{n}" }
  end
end
