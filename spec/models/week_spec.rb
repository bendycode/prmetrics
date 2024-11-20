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
        expect(week.open_prs).to include(open_pr)
        expect(week.open_prs).not_to include(draft_pr)
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
        expect(current_week.draft_prs).to include(draft_pr)
        expect(current_week.draft_prs).not_to include(regular_pr)
      end
    end

    describe '#started_prs' do
      let!(:pr_in_week) { create(:pull_request, repository: repository, gh_created_at: current_week.begin_date + 1.day) }
      let!(:pr_before_week) { create(:pull_request, repository: repository, gh_created_at: current_week.begin_date - 1.day) }

      it 'returns PRs created during the week' do
        expect(current_week.started_prs).to include(pr_in_week)
        expect(current_week.started_prs).not_to include(pr_before_week)
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
        expect(current_week.cancelled_prs).to include(cancelled_pr)
        expect(current_week.cancelled_prs).not_to include(merged_pr)
      end
    end

    describe '#avg_hours_to_first_review' do
      let(:pr) { create(:pull_request, repository: repository, ready_for_review_at: current_week.begin_date + 2.hours) }

      context 'with reviews' do
        before do
          create(:review, pull_request: pr, submitted_at: current_week.begin_date + 4.hours)
          create(:review, pull_request: pr, submitted_at: current_week.begin_date + 6.hours)
        end

        it 'calculates average hours between ready for review and first review' do
          expect(current_week.avg_hours_to_first_review).to eq(2.0)
        end
      end

      context 'without reviews' do
        it 'returns nil' do
          expect(current_week.avg_hours_to_first_review).to be_nil
        end
      end
    end

    describe '#avg_hours_to_merge' do
      let!(:merged_pr1) { create(:pull_request, repository: repository, ready_for_review_at: current_week.begin_date, gh_merged_at: current_week.begin_date + 4.hours) }
      let!(:merged_pr2) { create(:pull_request, repository: repository, ready_for_review_at: current_week.begin_date, gh_merged_at: current_week.begin_date + 8.hours) }

      before do
        merged_pr1.update(merged_week: current_week)
        merged_pr2.update(merged_week: current_week)
      end

      it 'calculates average hours between ready for review and merge' do
        expect(current_week.avg_hours_to_merge).to eq(6.0)
      end

      context 'without merged PRs' do
        before do
          PullRequest.destroy_all
        end

        it 'returns nil' do
          expect(current_week.avg_hours_to_merge).to be_nil
        end
      end
    end
  end
end
