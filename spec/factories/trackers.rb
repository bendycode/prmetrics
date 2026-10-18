FactoryBot.define do
  factory :tracker do
    kind { :github_issues }
    source_repository factory: :repository

    # A Shortcut tracker reads one workflow's stories with its own token
    trait :shortcut do
      kind { :shortcut }
      source_repository { nil }
      api_token { 'shortcut-test-token' }
      workflow_id { '100' }
    end

    # As trackers:create_github_issues sets one up: covering its own repository
    trait :covering_source do
      after(:create) { |tracker| tracker.source_repository.update!(tracker: tracker) }
    end
  end
end
