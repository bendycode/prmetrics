require 'rails_helper'

RSpec.describe WeekStatsService do
  let(:repository) { create(:repository) }
  let(:week) { create(:week, repository: repository, begin_date: 1.week.ago.beginning_of_week, end_date: 1.week.ago.end_of_week) }
  let(:service) { described_class.new(week) }

  describe '#update_stats' do
    context 'when calculating num_open_prs' do
      let!(:closed_after_wk) { create(:pull_request, repository: repository, state: 'open', draft: false, gh_created_at: 2.weeks.ago, gh_closed_at: 1.day.from_now) }
      let!(:closed_before_wk) { create(:pull_request, repository: repository, state: 'closed', draft: false, gh_created_at: 3.weeks.ago, gh_closed_at: 8.days.ago) }
      let!(:draft_pr) { create(:pull_request, repository: repository, state: 'open', draft: true, gh_created_at: 2.weeks.ago) }

      let!(:draft_removed_after_wk) {
        # PR created as draft during week, draft removed after week
        draft_pr = create(:pull_request, repository: repository, state: 'open', draft: true, gh_created_at: 5.days.ago)
        draft_pr.update(draft: false, ready_for_review_at: 1.day.from_now)
        draft_pr
      }
      let!(:opened_during_wk) { create(:pull_request, repository: repository, state: 'open', draft: false, gh_created_at: 7.days.ago) }

      before do
        service.update_stats
      end

      it 'correctly calculates num_open_prs' do
        expect(week.reload.num_open_prs).to eq(2)
      end
    end

    context 'when calculating num_prs_started' do
      before do
        create(:pull_request, repository: repository, draft: false, ready_for_review_at: week.begin_date + 1.day)
        create(:pull_request, repository: repository, draft: false, ready_for_review_at: week.begin_date - 1.day)
        create(:pull_request, repository: repository, draft: false, ready_for_review_at: week.end_date + 1.day)
        service.update_stats
      end

      it 'correctly calculates num_prs_started' do
        expect(week.reload.num_prs_started).to eq(1)
      end
    end

    context 'when calculating num_prs_merged' do
      before do
        create(:pull_request, repository: repository, gh_merged_at: week.begin_date + 1.day)
        create(:pull_request, repository: repository, gh_merged_at: week.begin_date - 1.day)
        create(:pull_request, repository: repository, gh_merged_at: week.end_date + 1.day)
        service.update_stats
      end

      it 'correctly calculates num_prs_merged' do
        expect(week.reload.num_prs_merged).to eq(1)
      end
    end

    context 'when calculating num_prs_initially_reviewed' do
      before do
        pr1 = create(:pull_request, repository: repository, ready_for_review_at: week.begin_date - 2.days)
        pr2 = create(:pull_request, repository: repository, ready_for_review_at: week.begin_date - 2.days)
        pr3 = create(:pull_request, repository: repository, ready_for_review_at: week.begin_date - 2.days)

        create(:review, pull_request: pr1, submitted_at: week.begin_date.in_time_zone + 1.day)
        create(:review, pull_request: pr1, submitted_at: week.begin_date.in_time_zone + 2.days)
        create(:review, pull_request: pr2, submitted_at: week.begin_date.in_time_zone - 1.day)
        create(:review, pull_request: pr3, submitted_at: week.end_date.in_time_zone + 1.day)

        service.update_stats
      end

      it 'correctly calculates num_prs_initially_reviewed' do
        expect(week.reload.num_prs_initially_reviewed).to eq(1)
      end
    end

    context 'when calculating num_prs_cancelled' do
      before do
        create(:pull_request, repository: repository, state: 'closed', gh_merged_at: nil, gh_closed_at: week.begin_date + 1.day)
        create(:pull_request, repository: repository, state: 'closed', gh_merged_at: nil, gh_closed_at: week.begin_date - 1.day)
        create(:pull_request, repository: repository, state: 'closed', gh_merged_at: nil, gh_closed_at: week.end_date + 1.day)
        create(:pull_request, repository: repository, state: 'closed', gh_merged_at: week.begin_date + 1.day, gh_closed_at: week.begin_date + 1.day)
        service.update_stats
      end

      it 'correctly calculates num_prs_cancelled' do
        expect(week.reload.num_prs_cancelled).to eq(1)
      end
    end

    context 'when calculating avg_hrs_to_first_review' do
      before do
        pr1 = create(:pull_request, repository: repository, ready_for_review_at: week.begin_date)
        pr2 = create(:pull_request, repository: repository, ready_for_review_at: week.begin_date)

        create(:review, pull_request: pr1, submitted_at: week.begin_date + 2.hours)
        create(:review, pull_request: pr2, submitted_at: week.begin_date + 4.hours)

        service.update_stats
      end

      it 'correctly calculates avg_hrs_to_first_review' do
        expect(week.reload.avg_hrs_to_first_review).to eq(3.0)
      end
    end

    context 'when calculating avg_hrs_to_merge' do
      before do
        create(:pull_request, repository: repository, ready_for_review_at: week.begin_date, gh_merged_at: week.begin_date + 3.hours)
        create(:pull_request, repository: repository, ready_for_review_at: week.begin_date, gh_merged_at: week.begin_date + 9.hours)
        service.update_stats
      end

      it 'correctly calculates avg_hrs_to_merge' do
        expect(week.reload.avg_hrs_to_merge).to eq(6.0)
      end
    end
  end
end
