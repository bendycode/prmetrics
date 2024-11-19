FactoryBot.define do
  factory :week do
    sequence(:week_number)
    repository { nil }
    begin_date { "2024-11-11" }
    end_date { "2024-11-17" }
    num_open_prs { 1 }
    num_prs_started { 1 }
    num_prs_merged { 1 }
    num_prs_initially_reviewed { 1 }
    num_prs_cancelled { 1 }
    avg_hrs_to_first_review { "9.99" }
    avg_hrs_to_merge { "9.99" }
  end
end
