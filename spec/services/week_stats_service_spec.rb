require 'rails_helper'

RSpec.describe WeekStatsService do
  let(:repository) { create(:repository) }
  # A fixed Monday-to-Sunday week, so a figure measured in weekday hours is the
  # same on every day the suite runs. Anchoring the week to the current date put
  # its begin_date on whatever day of the week it happened to be, and the
  # weekday-hour averages read zero whenever that was a Saturday or Sunday.
  let(:week) do
    create(:week, repository: repository, begin_date: Date.new(2026, 9, 14), end_date: Date.new(2026, 9, 20))
  end
  let(:service) { described_class.new(week) }

  describe '#update_stats' do
    context 'when calculating num_open_prs' do
      # Every time is placed by the week's own dates. The count asks where a
      # pull request stood when the week ended, so a time measured from the
      # day the suite runs moves across that boundary as the calendar does.
      # Two pull requests count, so that no expected figure matches the week
      # factory's default of one.
      let(:during_week) { week.begin_date.in_time_zone + 2.days }
      let(:week_end) { week.end_date.in_time_zone.end_of_day }
      let(:just_after_week) { week_end + 1.second }
      let!(:_closed_after_week) do
        create(:pull_request, repository: repository, gh_created_at: during_week, gh_closed_at: just_after_week)
      end
      let!(:_ready_as_week_ended) do
        create(:pull_request, repository: repository, gh_created_at: week_end, ready_for_review_at: week_end)
      end

      def open_count_after_update
        service.update_stats
        week.reload.num_open_prs
      end

      it 'counts pull requests open and ready for review at the last moment of the week' do
        expect(open_count_after_update).to be(2)
      end

      it 'leaves out a draft' do
        create(:pull_request, :draft, repository: repository, gh_created_at: during_week)

        expect(open_count_after_update).to be(2)
      end

      it 'leaves out a pull request created after the week ended' do
        create(:pull_request, repository: repository, gh_created_at: just_after_week)

        expect(open_count_after_update).to be(2)
      end

      it 'leaves out a pull request that became ready for review after the week ended' do
        create(:pull_request, repository: repository, gh_created_at: during_week,
                              ready_for_review_at: just_after_week)

        expect(open_count_after_update).to be(2)
      end

      it 'leaves out a pull request with a close date inside the week' do
        create(:pull_request, repository: repository, gh_created_at: during_week, gh_closed_at: week_end)

        expect(open_count_after_update).to be(2)
      end

      it 'leaves out a pull request that closed after the week ended' do
        create(:pull_request, repository: repository, state: 'closed', gh_created_at: during_week,
                              gh_closed_at: just_after_week)

        expect(open_count_after_update).to be(2)
      end
    end

    context 'when calculating num_prs_started' do
      before do
        create(:pull_request, repository: repository, draft: false, ready_for_review_at: week.begin_date + 1.day)
        create(:pull_request, repository: repository, draft: false, ready_for_review_at: week.begin_date + 2.days)
        # Hand-built to reach the draft condition: the sync leaves
        # ready_for_review_at empty on a draft.
        create(:pull_request, :draft, repository: repository, ready_for_review_at: week.begin_date + 3.days)
        create(:pull_request, repository: repository, draft: false, ready_for_review_at: week.begin_date - 1.day)
        create(:pull_request, repository: repository, draft: false, ready_for_review_at: week.end_date + 1.day)

        # Week associations are automatically updated by callbacks

        service.update_stats
      end

      it 'counts the non-draft pull requests that became ready for review during the week' do
        expect(week.reload.num_prs_started).to be(2)
      end
    end

    context 'when calculating num_prs_merged' do
      before do
        create(:pull_request, repository: repository, gh_merged_at: week.begin_date + 1.day)
        create(:pull_request, repository: repository, gh_merged_at: week.begin_date + 2.days)
        create(:pull_request, repository: repository, gh_merged_at: week.begin_date - 1.day)
        create(:pull_request, repository: repository, gh_merged_at: week.end_date + 1.day)

        # Week associations are automatically updated by callbacks

        service.update_stats
      end

      it 'counts pull requests merged during the week' do
        expect(week.reload.num_prs_merged).to be(2)
      end
    end

    context 'when calculating num_prs_initially_reviewed' do
      before do
        pr1 = create(:pull_request, repository: repository, ready_for_review_at: week.begin_date - 2.days)
        pr2 = create(:pull_request, repository: repository, ready_for_review_at: week.begin_date - 2.days)
        pr3 = create(:pull_request, repository: repository, ready_for_review_at: week.begin_date - 2.days)
        pr4 = create(:pull_request, repository: repository, ready_for_review_at: week.begin_date - 2.days)

        create(:review, pull_request: pr1, submitted_at: week.begin_date.in_time_zone + 1.day)
        create(:review, pull_request: pr1, submitted_at: week.begin_date.in_time_zone + 2.days)
        create(:review, pull_request: pr4, submitted_at: week.begin_date.in_time_zone + 3.days)
        # First reviewed before the week and again during it, so it belongs to
        # the earlier week.
        create(:review, pull_request: pr2, submitted_at: week.begin_date.in_time_zone - 1.day)
        create(:review, pull_request: pr2, submitted_at: week.begin_date.in_time_zone + 1.day)
        create(:review, pull_request: pr3, submitted_at: week.end_date.in_time_zone + 1.day)

        # Week associations are automatically updated by callbacks

        service.update_stats
      end

      it 'counts pull requests first reviewed during the week' do
        expect(week.reload.num_prs_initially_reviewed).to be(2)
      end
    end

    context 'when calculating num_prs_cancelled' do
      before do
        create(:pull_request, repository: repository, state: 'closed', gh_merged_at: nil,
                              gh_closed_at: week.begin_date + 1.day)
        create(:pull_request, repository: repository, state: 'closed', gh_merged_at: nil,
                              gh_closed_at: week.begin_date + 2.days)
        create(:pull_request, repository: repository, state: 'closed', gh_merged_at: nil,
                              gh_closed_at: week.begin_date - 1.day)
        create(:pull_request, repository: repository, state: 'closed', gh_merged_at: nil,
                              gh_closed_at: week.end_date + 1.day)
        create(:pull_request, repository: repository, state: 'closed', gh_merged_at: week.begin_date + 1.day,
                              gh_closed_at: week.begin_date + 1.day)
        # Hand-built to reach the state condition: the sync stores GitHub's
        # state and close date together, so a close date comes with state closed.
        create(:pull_request, repository: repository, state: 'open', gh_merged_at: nil,
                              gh_closed_at: week.begin_date + 3.days)

        # Week associations are automatically updated by callbacks

        service.update_stats
      end

      it 'counts pull requests closed unmerged during the week' do
        expect(week.reload.num_prs_cancelled).to be(2)
      end
    end

    context 'when calculating avg_hrs_to_first_review' do
      before do
        pr1 = create(:pull_request, repository: repository, ready_for_review_at: week.begin_date)
        pr2 = create(:pull_request, repository: repository, ready_for_review_at: week.begin_date)

        create(:review, pull_request: pr1, submitted_at: week.begin_date + 2.hours)
        create(:review, pull_request: pr2, submitted_at: week.begin_date + 4.hours)

        # Week associations are automatically updated by callbacks

        service.update_stats
      end

      it 'averages the weekday hours from ready for review to first review' do
        expect(week.reload.avg_hrs_to_first_review).to eq(3.0)
      end
    end

    context 'when calculating avg_hrs_to_merge' do
      before do
        create(:pull_request, repository: repository, ready_for_review_at: week.begin_date,
                              gh_merged_at: week.begin_date + 3.hours)
        create(:pull_request, repository: repository, ready_for_review_at: week.begin_date,
                              gh_merged_at: week.begin_date + 9.hours)

        # Week associations are automatically updated by callbacks

        service.update_stats
      end

      it 'averages the weekday hours from ready for review to merge' do
        expect(week.reload.avg_hrs_to_merge).to eq(6.0)
      end
    end

    context 'when counting and timing approvals' do
      # Monday 09:00 through Friday, so a weekend-spanning window is visible.
      # The week has to exist before a pull request, or saving one creates its own.
      let!(:week) do
        create(:week, repository: repository, week_number: 202_637,
                      begin_date: Date.new(2026, 9, 14), end_date: Date.new(2026, 9, 20))
      end
      let(:monday) { Time.zone.parse('2026-09-14 09:00') }
      let(:author) { create(:contributor) }

      def approved_pull_request(ready:, approved: nil, merged_by: nil, merged_at: nil)
        pull_request = create(:pull_request, repository: repository, author: author, gh_created_at: ready,
                                             ready_for_review_at: ready, merged_by: merged_by, gh_merged_at: merged_at)
        create(:review, pull_request: pull_request, state: 'APPROVED', submitted_at: approved) if approved
        pull_request.ensure_weeks_exist_and_update_associations
        pull_request
      end

      it 'counts the pull requests first approved during the week' do
        approved_pull_request(ready: monday, approved: monday + 2.hours)
        approved_pull_request(ready: monday, merged_by: author, merged_at: monday + 4.hours)
        approved_pull_request(ready: monday)

        service.update_stats

        expect(week.reload.num_prs_approved).to be(2)
      end

      it 'averages the weekday hours from ready for review to approval, self-merges included' do
        approved_pull_request(ready: monday, approved: monday + 2.hours)
        approved_pull_request(ready: monday, merged_by: author, merged_at: monday + 4.hours)

        service.update_stats

        expect(week.reload.avg_hrs_to_approval).to eq(3.0)
      end

      it 'leaves the weekend out of the wait' do
        friday_before = Time.zone.parse('2026-09-11 16:00')
        approved_pull_request(ready: friday_before, approved: friday_before + 3.days)

        service.update_stats

        expect(week.reload.avg_hrs_to_approval).to eq(24.0)
      end

      it 'clears a stale approval figure when the week no longer has one' do
        week.update!(num_prs_approved: 7, avg_hrs_to_approval: 9.99)

        service.update_stats

        expect(week.reload).to have_attributes(num_prs_approved: 0, avg_hrs_to_approval: nil)
      end
    end

    context 'when timing first feedback across a weekend' do
      let!(:week) do
        create(:week, repository: repository, week_number: 202_637,
                      begin_date: Date.new(2026, 9, 14), end_date: Date.new(2026, 9, 20))
      end

      it 'leaves the weekend out of the wait' do
        friday_before = Time.zone.parse('2026-09-11 16:00')
        pull_request = create(:pull_request, repository: repository, gh_created_at: friday_before,
                                             ready_for_review_at: friday_before)
        create(:review, pull_request: pull_request, state: 'COMMENTED', submitted_at: friday_before + 3.days)
        pull_request.ensure_weeks_exist_and_update_associations

        service.update_stats

        expect(week.reload.avg_hrs_to_first_review).to eq(24.0)
      end
    end

    describe '#calculate_num_prs_late' do
      # Late and stale count days from the week's end_date, so these fixtures are
      # placed relative to the week rather than to the current date. Measuring the
      # fixture from today only agreed with the metric while the week ended today.
      context 'with PRs at various approval ages' do
        before do
          [2, 10, 15, 30].each do |days|
            create(:pull_request, :approved_before_week_end,
                   repository: repository, week: week, days_before_week_end: days)
          end
        end

        it 'counts only PRs approved 8 to 27 days before the week ended' do
          expect(service.send(:calculate_num_prs_late)).to be(2)
        end
      end

      context 'edge cases' do
        # One pull request is late in every example, so an expected figure of
        # zero cannot pass when nothing is counted.
        let!(:_late_pr) do
          create(:pull_request, :approved_before_week_end, repository: repository, week: week,
                                                           days_before_week_end: 10)
        end

        # Merged and closed are judged as of the week's end, not as of today, so a
        # fixture that merges after the week ended is still late for that week.
        # The merged fixture has no close date, so only its merge date can
        # exclude it.
        it 'excludes PRs merged before the week ended' do
          create(:pull_request, :approved_before_week_end, repository: repository, week: week,
                                                           days_before_week_end: 10,
                                                           gh_merged_at: week.end_date - 1.day)
          expect(service.send(:calculate_num_prs_late)).to be(1)
        end

        it 'excludes PRs closed unmerged before the week ended' do
          create(:pull_request, :approved_before_week_end, repository: repository, week: week,
                                                           days_before_week_end: 10,
                                                           gh_closed_at: week.end_date - 1.day, gh_merged_at: nil)
          expect(service.send(:calculate_num_prs_late)).to be(1)
        end

        it 'excludes draft PRs even if approved' do
          create(:pull_request, :approved_before_week_end, repository: repository, week: week,
                                                           days_before_week_end: 10, draft: true)
          expect(service.send(:calculate_num_prs_late)).to be(1)
        end
      end
    end

    describe '#calculate_num_prs_stale' do
      it 'counts only PRs approved 28+ days ago' do
        create(:pull_request, :approved_before_week_end,
               repository: repository, week: week, days_before_week_end: 27)
        create(:pull_request, :approved_before_week_end,
               repository: repository, week: week, days_before_week_end: 28)
        create(:pull_request, :approved_before_week_end,
               repository: repository, week: week, days_before_week_end: 60)

        expect(service.send(:calculate_num_prs_stale)).to eq(2)
      end
    end

    describe '#update_stats' do
      it 'populates num_prs_late and num_prs_stale columns' do
        create(:pull_request, :approved_before_week_end,
               repository: repository, week: week, days_before_week_end: 10)
        create(:pull_request, :approved_before_week_end,
               repository: repository, week: week, days_before_week_end: 35)

        service.update_stats

        expect(week.reload.num_prs_late).to eq(1)
        expect(week.reload.num_prs_stale).to eq(1)
      end
    end
  end

  describe '.generate_weeks_for_repository' do
    context 'with PR date in early January belonging to previous year week' do
      # Jan 2, 2026 is in the week of Mon Dec 29, 2025 - Sun Jan 4, 2026
      let!(:january_pr) do
        create(:pull_request,
               repository: repository,
               gh_created_at: Time.zone.local(2026, 1, 2, 10, 0, 0))
      end

      it 'generates week_number from Monday date, not PR date' do
        described_class.generate_weeks_for_repository(repository)

        expect(repository.weeks.find_by(begin_date: Date.new(2025, 12, 29))).to have_attributes(
          week_number: 202_552,
          end_date: Date.new(2026, 1, 4)
        )
      end
    end
  end
end
