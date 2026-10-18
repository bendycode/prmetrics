FactoryBot.define do
  factory :story do
    tracker
    sequence(:external_id, &:to_s)
    key { "PRM-#{external_id}" }
    title { 'Measure something' }
    url { "https://github.com/owner/repository/issues/#{external_id}" }
    state { 'open' }
    source_created_at { Time.zone.parse('2026-09-01 10:00') }
    source_updated_at { source_created_at }
    listed_at { source_updated_at }
  end
end
