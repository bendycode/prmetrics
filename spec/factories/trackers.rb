FactoryBot.define do
  factory :tracker do
    kind { :github_issues }
    source_repository factory: :repository

    # As trackers:create_github_issues sets one up: covering its own repository
    trait :covering_source do
      after(:create) { |tracker| tracker.source_repository.update!(tracker: tracker) }
    end
  end
end
