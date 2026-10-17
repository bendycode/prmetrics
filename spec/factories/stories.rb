FactoryBot.define do
  factory :story do
    tracker
    sequence(:external_id, &:to_s)
    key { "PRM-#{external_id}" }
    title { 'Measure something' }
    url { "https://github.com/owner/repository/issues/#{external_id}" }
    state { 'open' }
    gh_created_at { 1.week.ago }
    gh_updated_at { gh_created_at }
  end
end
