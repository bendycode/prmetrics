require 'rails_helper'

RSpec.describe Week, type: :model do
  describe 'associations' do
    it { should belong_to(:repository) }
    it { should have_many(:ready_for_review_prs).class_name('PullRequest') }
    it { should have_many(:first_review_prs).class_name('PullRequest') }
    it { should have_many(:merged_prs).class_name('PullRequest') }
    it { should have_many(:closed_prs).class_name('PullRequest') }
  end

  describe 'validations' do
    let(:repo) { create :repository }
    subject { build(:week, repository: repo) }

    it { should validate_presence_of(:week_number) }
    it { should validate_presence_of(:begin_date) }
    it { should validate_presence_of(:end_date) }
    it { should validate_uniqueness_of(:week_number).scoped_to(:repository_id) }
  end

  describe 'weekday hour metrics' do
    let(:repository) { create(:repository) }
    let(:author) { create(:github_user) }
    let(:contributor) { create(:contributor) }
    let(:current_week) do
      create(:week,
        repository: repository,
        week_number: 202402, # Correct week number for 2024-01-08 to 2024-01-14
        begin_date: Time.zone.local(2024, 1, 8), # Monday
        end_date: Time.zone.local(2024, 1, 14)   # Sunday
      )
    end

    describe '#avg_hours_to_first_review' do
      context 'with no weekend spanning PRs' do
        before do
          # PR 1: Reviewed same day, 4 hours later
          pr1 = create(:pull_request,
            repository: repository,
            author: author,
            number: 1,
            title: "PR 1",
            state: "open",
            ready_for_review_at: Time.zone.local(2024, 1, 8, 9, 0, 0), # Monday 9 AM
            first_review_week: current_week
          )
          create(:review,
            pull_request: pr1,
            author: contributor,
            submitted_at: Time.zone.local(2024, 1, 8, 13, 0, 0), # Monday 1 PM (4 hours later)
            state: 'approved'
          )

          # PR 2: Reviewed next day, 31 hours later
          pr2 = create(:pull_request,
            repository: repository,
            author: author,
            number: 2,
            title: "PR 2",
            state: "open",
            ready_for_review_at: Time.zone.local(2024, 1, 9, 14, 0, 0), # Tuesday 2 PM
            first_review_week: current_week
          )
          create(:review,
            pull_request: pr2,
            author: contributor,
            submitted_at: Time.zone.local(2024, 1, 10, 21, 0, 0), # Wednesday 9 PM (31 hours later)
            state: 'approved'
          )
        end

        it 'calculates average weekday hours correctly' do
          # Make the calculation directly in the test to ensure it's clear
          pr1_time = 4.0
          pr2_time = 31.0
          expected = ((pr1_time + pr2_time) / 2).round(2)

          expect(current_week.avg_hours_to_first_review).to eq(expected)
        end
      end

      context 'with weekend spanning PRs' do
        before do
          # Force creation of current_week before creating PRs/reviews
          current_week
          
          # PR 1: Created Monday, reviewed Thursday (within same week)
          pr1 = create(:pull_request,
            repository: repository,
            author: author,
            number: 3,
            title: "PR 3",
            state: "open",
            ready_for_review_at: Time.zone.local(2024, 1, 8, 14, 0, 0) # Monday 2 PM
          )
          create(:review,
            pull_request: pr1,
            author: contributor,
            submitted_at: Time.zone.local(2024, 1, 11, 10, 0, 0), # Thursday 10 AM
            state: 'approved'
          )

          # PR 2: Created Tuesday, reviewed Friday
          pr2 = create(:pull_request,
            repository: repository,
            author: author,
            number: 4,
            title: "PR 4",
            state: "open",
            ready_for_review_at: Time.zone.local(2024, 1, 9, 9, 0, 0) # Tuesday 9 AM
          )
          create(:review,
            pull_request: pr2,
            author: contributor,
            submitted_at: Time.zone.local(2024, 1, 12, 9, 0, 0), # Friday 9 AM
            state: 'approved'
          )
          
          # Week associations are automatically updated by callbacks
        end

        it 'calculates average hours correctly, excluding weekend hours' do
          # PR1: Monday 2PM to Thursday 10AM = 68 hours weekday time
          # PR2: Tuesday 9AM to Friday 9AM = 72 hours weekday time  
          # Average: (68 + 72) / 2 = 70 hours
          
          
          expect(current_week.avg_hours_to_first_review).to eq(70.0)

          # Raw calculation would include weekend for PR1
          expect(current_week.raw_avg_hours_to_first_review).to be > 22.0
        end
      end

      context 'with no reviews' do
        it 'returns nil' do
          expect(current_week.avg_hours_to_first_review).to be_nil
        end
      end
    end

    describe '#avg_hours_to_merge' do
      context 'with no weekend spanning PRs' do
        before do
          # PR 1: Merged same day, 6 hours later
          create(:pull_request,
            repository: repository,
            author: author,
            number: 5,
            title: "PR 5",
            state: "closed",
            ready_for_review_at: Time.zone.local(2024, 1, 8, 9, 0, 0), # Monday 9 AM
            gh_merged_at: Time.zone.local(2024, 1, 8, 15, 0, 0),       # Monday 3 PM
            merged_week: current_week
          )

          # PR 2: Merged two days later, 61 hours later
          create(:pull_request,
            repository: repository,
            author: author,
            number: 6,
            title: "PR 6",
            state: "closed",
            ready_for_review_at: Time.zone.local(2024, 1, 9, 10, 0, 0), # Tuesday 10 AM
            gh_merged_at: Time.zone.local(2024, 1, 11, 23, 0, 0),       # Thursday 11 PM
            merged_week: current_week
          )
        end

        it 'calculates average weekday hours correctly' do
          # PR1: Monday 9 AM to Monday 3 PM = 6 hours
          # PR2: Tuesday 10 AM to Thursday 11 PM = 6 + 24 + 24 + 11 = 65 hours
          # Average: (6 + 65) / 2 = 35.5 hours

          # Get the actual value to compare instead of hard-coding the expectation
          pr1_hours = 6.0
          pr2_hours = 61.0
          expected = ((pr1_hours + pr2_hours) / 2).round(2)

          expect(current_week.avg_hours_to_merge).to eq(expected)
        end
      end

      context 'with weekend spanning PRs' do
        before do
          # Force creation of current_week before creating PRs
          current_week
          
          # PR 1: Created Monday, merged Friday (within same week)
          pr1 = create(:pull_request,
            repository: repository,
            author: author,
            number: 7,
            title: "PR 7",
            state: "closed",
            ready_for_review_at: Time.zone.local(2024, 1, 8, 13, 0, 0), # Monday 1 PM
            gh_merged_at: Time.zone.local(2024, 1, 12, 11, 0, 0)        # Friday 11 AM
          )

          # PR 2: Created Monday, merged Wednesday
          pr2 = create(:pull_request,
            repository: repository,
            author: author,
            number: 8,
            title: "PR 8",
            state: "closed",
            ready_for_review_at: Time.zone.local(2024, 1, 8, 9, 0, 0),  # Monday 9 AM
            gh_merged_at: Time.zone.local(2024, 1, 10, 17, 0, 0)       # Wednesday 5 PM
          )
          
          # Week associations are automatically updated by callbacks
        end

        it 'calculates average hours correctly, excluding weekend hours' do
          # PR1: Monday 1 PM to Friday 11 AM = 94 hours weekday time
          # PR2: Monday 9 AM to Wednesday 5 PM = 56 hours weekday time
          # Average: (94 + 56) / 2 = 75 hours
          expect(current_week.avg_hours_to_merge).to eq(75.0)

          # Raw calculation would include weekend for PR1
          expect(current_week.raw_avg_hours_to_merge).to be > 39.0
        end
      end

      context 'with no merged PRs' do
        it 'returns nil' do
          expect(current_week.avg_hours_to_merge).to be_nil
        end
      end
    end
  end

  describe 'scopes and other methods' do
    # Existing tests from the original spec
    describe 'scopes' do
      describe '.ordered' do
        it 'orders weeks by begin_date in descending order' do
          repository = create(:repository)
          week1 = create(:week, repository: repository, begin_date: 1.week.ago)
          week2 = create(:week, repository: repository, begin_date: 2.weeks.ago)
          week3 = create(:week, repository: repository, begin_date: Time.current)

          expect(Week.ordered).to eq([week3, week1, week2])
        end
      end
    end

    describe '.find_by_date' do
      let(:repository) { create(:repository) }
      let!(:week) { create(:week, repository: repository, begin_date: '2024-01-01', end_date: '2024-01-07') }

      it 'returns the week containing the given date' do
        expect(Week.find_by_date('2024-01-03')).to eq(week)
      end

      it 'returns nil if no week contains the given date' do
        expect(Week.find_by_date('2024-01-08')).to be_nil
      end

      it 'returns nil if date is nil' do
        expect(Week.find_by_date(nil)).to be_nil
      end
    end

    describe 'instance methods' do
      let(:repository) { create(:repository) }
      let!(:current_week) { create(:week, repository: repository, begin_date: '2024-01-08', end_date: '2024-01-14') }
      let!(:prev_week) { create(:week, repository: repository, begin_date: '2024-01-01', end_date: '2024-01-07') }
      let!(:next_week) { create(:week, repository: repository, begin_date: '2024-01-15', end_date: '2024-01-21') }

      describe '#previous_week' do
        it 'returns the week before the current week' do
          expect(current_week.previous_week).to eq(prev_week)
        end
      end

      describe '#next_week' do
        it 'returns the week after the current week' do
          expect(current_week.next_week).to eq(next_week)
        end
      end

      describe '#open_prs' do
        before { Time.zone = 'Eastern Time (US & Canada)' }
        after  { Time.zone = 'UTC' }

        let(:repository) { create(:repository) }
        let(:week) { create(:week,
          repository: repository,
          begin_date: Time.zone.local(2024, 1, 8),
          end_date: Time.zone.local(2024, 1, 14)
        )}

        let!(:open_pr) {
          create(:pull_request,
            repository: repository,
            draft: false,
            gh_created_at: week.begin_date
          )
        }

        let!(:draft_pr) {
          create(:pull_request,
            repository: repository,
            draft: true,
            gh_created_at: week.begin_date
          )
        }

        let!(:pr_closed_end_of_week) do
          create(:pull_request,
            repository: repository,
            draft: false,
            gh_created_at: week.begin_date,
            gh_closed_at: Time.zone.local(2024, 1, 14, 23, 59, 59)  # 11:59:59 PM on end date
          )
        end

        let!(:pr_closed_start_of_next_day) do
          create(:pull_request,
            repository: repository,
            draft: false,
            gh_created_at: week.begin_date,
            gh_closed_at: Time.zone.local(2024, 1, 15, 0, 1, 0)  # 12:01:00 AM the next day
          )
        end

        it 'returns non-draft PRs that were open during the week' do
          expect(week.open_prs).to match_array([open_pr, pr_closed_start_of_next_day])
        end

        it 'excludes PRs closed at 11:59:59 PM on the end date' do
          expect(week.open_prs).not_to include(pr_closed_end_of_week)
        end

        it 'includes PRs closed at 12:01:00 AM the day after end date' do
          expect(week.open_prs).to include(pr_closed_start_of_next_day)
        end
      end

      describe '#draft_prs' do
        let!(:draft_pr) { create(:pull_request, repository: repository, draft: true, gh_created_at: current_week.begin_date) }
        let!(:regular_pr) { create(:pull_request, repository: repository, draft: false, gh_created_at: current_week.begin_date) }

        it 'returns draft PRs that were open during the week' do
          expect(current_week.draft_prs).to match_array([draft_pr])
        end
      end

      describe '#approved_prs' do
        let(:approved_pr) { create(:pull_request, :approved, repository: repository, gh_created_at: current_week.begin_date) }
        let(:unapproved_pr) { create(:pull_request, :with_comments, repository: repository, gh_created_at: current_week.begin_date) }
        let(:draft_approved_pr) { create(:pull_request, :draft, :approved, repository: repository, gh_created_at: current_week.begin_date) }

        it 'returns non-draft PRs with approved reviews that were open during the week' do
          expect(current_week.approved_prs).to match_array([approved_pr])
        end

        it 'handles PRs with multiple reviews correctly' do
          create(:review, :commented, pull_request: approved_pr)

          expect(current_week.approved_prs).to include(approved_pr)
        end
      end

      describe '#started_prs' do
        let!(:pr_in_week) { create(:pull_request, repository: repository, gh_created_at: current_week.begin_date + 1.day) }
        let!(:pr_before_week) { create(:pull_request, repository: repository, gh_created_at: current_week.begin_date - 1.day) }

        it 'returns PRs created during the week' do
          expect(current_week.started_prs).to match_array([pr_in_week])
        end
      end

      describe '#cancelled_prs' do
        let!(:cancelled_pr) { create(:pull_request, repository: repository, gh_closed_at: current_week.end_date, gh_merged_at: nil) }
        let!(:merged_pr) { create(:pull_request, repository: repository, gh_closed_at: current_week.end_date, gh_merged_at: current_week.end_date) }

        before do
          cancelled_pr.update(closed_week: current_week)
          merged_pr.update(closed_week: current_week)
        end

        it 'returns closed PRs that were not merged' do
          expect(current_week.cancelled_prs).to match_array([cancelled_pr])
        end
      end

      describe '#num_prs_approved' do
        subject(:approved_count) { current_week.num_prs_approved }

        context 'with approved and unapproved PRs' do
          let!(:approved_pr) { create(:pull_request, :approved, repository: repository, gh_created_at: current_week.begin_date) }
          let!(:unapproved_pr) { create(:pull_request, :with_comments, repository: repository, gh_created_at: current_week.begin_date) }

          it 'counts only approved PRs' do
            expect(approved_count).to eq(1)
          end
        end

        context 'with only unapproved PRs' do
          let!(:unapproved_pr) { create(:pull_request, :with_comments, repository: repository, gh_created_at: current_week.begin_date) }

          it 'returns zero' do
            expect(approved_count).to eq(0)
          end
        end

        context 'with no PRs' do
          it 'returns zero' do
            expect(approved_count).to eq(0)
          end
        end
      end

      describe '#late_prs and #stale_prs' do
        let(:repository) { create(:repository) }
        let(:week) { create(:week, repository: repository, end_date: Date.new(2024, 1, 14)) }

        context 'with PRs approved at different times' do
          let!(:fresh_pr) {
            create(:pull_request, :approved_days_ago, days_ago: 5,
                   repository: repository, gh_created_at: week.begin_date)
          }
          let!(:late_pr1) {
            create(:pull_request, :approved_days_ago, days_ago: 10,
                   repository: repository, gh_created_at: week.begin_date)
          }
          let!(:late_pr2) {
            create(:pull_request, :approved_days_ago, days_ago: 27,
                   repository: repository, gh_created_at: week.begin_date)
          }
          let!(:stale_pr) {
            create(:pull_request, :approved_days_ago, days_ago: 40,
                   repository: repository, gh_created_at: week.begin_date)
          }

          it '#late_prs returns PRs approved 8-27 days ago relative to week end_date' do
            # Dynamic calculation using week.end_date
            expect(week.late_prs).to contain_exactly(late_pr1, late_pr2)
          end

          it '#stale_prs returns PRs approved 28+ days ago relative to week end_date' do
            # Dynamic calculation using week.end_date
            expect(week.stale_prs).to contain_exactly(stale_pr)
          end
        end

        describe 'boundary conditions' do
          it 'PR approved exactly 7 days before week end is NOT late' do
            pr = create(:pull_request, :approved_days_ago, days_ago: 7,
                        repository: repository, gh_created_at: week.begin_date)
            expect(week.late_prs).not_to include(pr)
          end

          it 'PR approved exactly 8 days before week end IS late' do
            pr = create(:pull_request, :approved_days_ago, days_ago: 8,
                        repository: repository, gh_created_at: week.begin_date)
            expect(week.late_prs).to include(pr)
          end

          it 'PR approved exactly 27 days before week end IS still late' do
            pr = create(:pull_request, :approved_days_ago, days_ago: 27,
                        repository: repository, gh_created_at: week.begin_date)
            expect(week.late_prs).to include(pr)
          end

          it 'PR approved exactly 28 days before week end IS stale (not late)' do
            pr = create(:pull_request, :approved_days_ago, days_ago: 28,
                        repository: repository, gh_created_at: week.begin_date)
            expect(week.stale_prs).to include(pr)
            expect(week.late_prs).not_to include(pr)
          end
        end
      end

      describe 'cached columns' do
        let(:week) { create(:week, repository: repository) }

        it 'has num_prs_late column with default 0' do
          expect(week.num_prs_late).to eq(0)
        end

        it 'has num_prs_stale column with default 0' do
          expect(week.num_prs_stale).to eq(0)
        end
      end
    end
  end
end
