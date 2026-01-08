FactoryBot.define do
  factory :week do
    sequence(:week_number)
    repository
    begin_date { 1.week.ago.beginning_of_week }
    end_date { 1.week.ago.end_of_week }
    num_open_prs { 1 }
    num_prs_started { 1 }
    num_prs_merged { 1 }
    num_prs_initially_reviewed { 1 }
    num_prs_cancelled { 1 }
    avg_hrs_to_first_review { '9.99' }
    avg_hrs_to_merge { '9.99' }

    # Year boundary week: Dec 29, 2025 - Jan 4, 2026
    trait :dec_2025_year_boundary do
      week_number { 202_552 }
      begin_date { Date.new(2025, 12, 29) }
      end_date { Date.new(2026, 1, 4) }
    end

    # Buggy year boundary week (week_number ending in 00)
    trait :dec_2025_year_boundary_buggy do
      week_number { 202_600 }
      begin_date { Date.new(2025, 12, 29) }
      end_date { Date.new(2026, 1, 4) }
    end
  end
end
