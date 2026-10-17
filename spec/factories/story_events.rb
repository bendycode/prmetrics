FactoryBot.define do
  factory :story_event do
    story
    sequence(:external_id, &:to_s)
    kind { :assigned }
    occurred_at { story.gh_created_at }
  end
end
