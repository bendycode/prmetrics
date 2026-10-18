FactoryBot.define do
  factory :story do
    tracker
    sequence(:external_id, &:to_s)
    key { "PRM-#{external_id}" }
    title { 'Measure something' }
    url { "https://github.com/owner/repository/issues/#{external_id}" }
    state { 'open' }
    gh_created_at { Time.zone.parse('2026-09-01 10:00') }
    gh_updated_at { gh_created_at }
    listed_at { gh_updated_at }
  end
end
