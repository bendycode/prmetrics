FactoryBot.define do
  factory :tracker do
    kind { :github_issues }
    source_repository factory: :repository
  end
end
