require 'rails_helper'

RSpec.describe Week do
  # Sets the week directly; saving would otherwise re-derive it from dates
  def pull_request_in_week(foreign_key, *traits)
    build(:pull_request, *traits, repository: week.repository, foreign_key => week.id)
      .tap(&:skip_week_association_update!).tap(&:save!)
  end

  describe 'associations' do
    it { is_expected.to belong_to(:repository) }
    it { is_expected.to have_many(:ready_for_review_prs).class_name('PullRequest') }
    it { is_expected.to have_many(:first_review_prs).class_name('PullRequest') }
    it { is_expected.to have_many(:merged_prs).class_name('PullRequest') }
    it { is_expected.to have_many(:closed_prs).class_name('PullRequest') }
  end

  describe 'pull requests counted toward the week' do
    let(:week) { create(:week) }

    %i[ready_for_review_prs first_review_prs first_approval_prs merged_prs closed_prs].each do |association|
      it "leaves promotions out of #{association}" do
        foreign_key = described_class.reflect_on_association(association).foreign_key
        development = pull_request_in_week(foreign_key)
        pull_request_in_week(foreign_key, :promotion)

        expect(week.public_send(association)).to contain_exactly(development)
      end
    end
  end

  describe 'late and stale pull requests' do
    let(:week) do
      create(:week, repository: create(:repository), week_number: 202_637,
                    begin_date: Date.new(2026, 9, 14), end_date: Date.new(2026, 9, 20))
    end
    let(:approved_at) { Time.zone.parse('2026-08-31 09:00') }

    def waiting_pull_request(approved_by:, approved: approved_at)
      pull_request = create(:pull_request, repository: week.repository, gh_created_at: approved - 1.day,
                                           ready_for_review_at: approved - 1.day)
      create(:review, pull_request: pull_request, state: 'APPROVED', submitted_at: approved, author: approved_by)
      pull_request
    end

    it 'counts a pull request a person approved and nobody merged' do
      waiting = waiting_pull_request(approved_by: create(:contributor))

      expect(week.late_prs).to contain_exactly(waiting)
    end

    it 'leaves out a pull request only a bot approved' do
      waiting_pull_request(approved_by: create(:contributor, bot: true))

      expect(week.late_prs).to be_empty
    end

    it 'counts a pull request approved long enough ago as stale rather than late' do
      long_ago = Time.zone.parse('2026-08-01 09:00')
      waiting = waiting_pull_request(approved_by: create(:contributor), approved: long_ago)

      expect(week.stale_prs).to contain_exactly(waiting)
    end

    it 'leaves a bot-approved pull request out of the stale list too' do
      long_ago = Time.zone.parse('2026-08-01 09:00')
      waiting_pull_request(approved_by: create(:contributor, bot: true), approved: long_ago)

      expect(week.stale_prs).to be_empty
    end
  end

  describe '.unreferenced' do
    let(:week) { create(:week) }

    it 'finds a week no pull request points at' do
      expect(week.repository.weeks.unreferenced).to contain_exactly(week)
    end

    %i[ready_for_review_prs first_review_prs first_approval_prs merged_prs closed_prs].each do |association|
      it "keeps a week a #{association.to_s.sub('_prs', '')} pull request points at, promotion or not" do
        foreign_key = described_class.reflect_on_association(association).foreign_key
        pull_request_in_week(foreign_key, :promotion)

        expect(week.repository.weeks.unreferenced).to be_empty
      end
    end
  end

  describe 'validations' do
    subject { build(:week, repository: repo) }

    let(:repo) { create(:repository) }

    it { is_expected.to validate_presence_of(:week_number) }
    it { is_expected.to validate_presence_of(:begin_date) }
    it { is_expected.to validate_presence_of(:end_date) }
    it { is_expected.to validate_uniqueness_of(:week_number).scoped_to(:repository_id) }
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

        it 'breaks ties on begin_date so paginated pages stay stable' do
          # Two weeks can share a begin_date -- the year-boundary week_number bug
          # produced exactly that, and db/data carries a repair for it. Ordering
          # on begin_date alone leaves tied rows in an order the database is free
          # to vary between queries, so under the LIMIT/OFFSET the repository page
          # now paginates with, a tied week can land on two pages or on none.
          repository = create(:repository)
          shared_date = Date.new(2025, 12, 29)
          first = create(:week, repository: repository, week_number: 202_552,
                                begin_date: shared_date, end_date: shared_date + 6)
          second = create(:week, repository: repository, week_number: 202_600,
                                 begin_date: shared_date, end_date: shared_date + 6)

          expect(repository.weeks.ordered).to eq([second, first])
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

      describe 'neighbours when two weeks share a begin_date' do
        it 'reaches each tied week from the other' do
          repository = create(:repository)
          shared = Date.new(2025, 12, 29)
          first = create(:week, repository: repository, week_number: 202_552,
                                begin_date: shared, end_date: shared + 6)
          second = create(:week, repository: repository, week_number: 202_600,
                                 begin_date: shared, end_date: shared + 6)

          expect(first.next_week).to eq(second)
          expect(second.previous_week).to eq(first)
        end
      end

      describe '#next_week' do
        it 'returns the week after the current week' do
          expect(current_week.next_week).to eq(next_week)
        end
      end

      describe '#open_prs' do
        around do |example|
          Time.use_zone('Eastern Time (US & Canada)') { example.run }
        end

        let(:repository) { create(:repository) }
        let(:week) do
          create(:week,
                 repository: repository,
                 begin_date: Time.zone.local(2024, 1, 8),
                 end_date: Time.zone.local(2024, 1, 14))
        end

        let!(:open_pr) do
          create(:pull_request,
                 repository: repository,
                 draft: false,
                 gh_created_at: week.begin_date)
        end

        let!(:draft_pr) do
          create(:pull_request,
                 repository: repository,
                 draft: true,
                 gh_created_at: week.begin_date)
        end

        let!(:pr_closed_end_of_week) do
          create(:pull_request,
                 repository: repository,
                 draft: false,
                 gh_created_at: week.begin_date,
                 gh_closed_at: Time.zone.local(2024, 1, 14, 23, 59, 59)) # 11:59:59 PM on end date
        end

        let!(:pr_closed_start_of_next_day) do
          create(:pull_request,
                 repository: repository,
                 draft: false,
                 gh_created_at: week.begin_date,
                 gh_closed_at: Time.zone.local(2024, 1, 15, 0, 1, 0)) # 12:01:00 AM the next day
        end

        it 'returns non-draft PRs open during the week, excluding those closed at end-of-day boundary' do
          # Tests important boundary: PRs closed at 11:59:59 PM on end_date are excluded,
          # but PRs closed after midnight are included
          expect(week.open_prs).to contain_exactly(open_pr, pr_closed_start_of_next_day)
        end
      end

      describe '#draft_prs' do
        let!(:draft_pr) do
          create(:pull_request, repository: repository, draft: true, gh_created_at: current_week.begin_date)
        end
        let!(:regular_pr) do
          create(:pull_request, repository: repository, draft: false, gh_created_at: current_week.begin_date)
        end

        it 'returns draft PRs that were open during the week' do
          expect(current_week.draft_prs).to contain_exactly(draft_pr)
        end
      end

      describe '#approved_prs' do
        let(:approved_pr) do
          create(:pull_request, :approved, repository: repository, gh_created_at: current_week.begin_date)
        end
        let(:unapproved_pr) do
          create(:pull_request, :with_comments, repository: repository, gh_created_at: current_week.begin_date)
        end
        let(:draft_approved_pr) do
          create(:pull_request, :draft, :approved, repository: repository, gh_created_at: current_week.begin_date)
        end

        it 'returns non-draft PRs with approved reviews that were open during the week' do
          expect(current_week.approved_prs).to contain_exactly(approved_pr)
        end

        it 'handles PRs with multiple reviews correctly' do
          create(:review, :commented, pull_request: approved_pr)

          expect(current_week.approved_prs).to include(approved_pr)
        end
      end

      describe '#started_prs' do
        let!(:pr_in_week) do
          create(:pull_request, repository: repository, gh_created_at: current_week.begin_date + 1.day)
        end
        let!(:pr_before_week) do
          create(:pull_request, repository: repository, gh_created_at: current_week.begin_date - 1.day)
        end

        it 'returns PRs created during the week' do
          expect(current_week.started_prs).to contain_exactly(pr_in_week)
        end
      end

      describe '#cancelled_prs' do
        let!(:cancelled_pr) do
          create(:pull_request, repository: repository, gh_closed_at: current_week.end_date, gh_merged_at: nil)
        end
        let!(:merged_pr) do
          create(:pull_request, repository: repository, gh_closed_at: current_week.end_date,
                                gh_merged_at: current_week.end_date)
        end

        before do
          cancelled_pr.update(closed_week: current_week)
          merged_pr.update(closed_week: current_week)
        end

        it 'returns closed PRs that were not merged' do
          expect(current_week.cancelled_prs).to contain_exactly(cancelled_pr)
        end
      end

      describe '#late_prs and #stale_prs' do
        let(:repository) { create(:repository) }
        let(:week) { create(:week, repository: repository, begin_date: 1.week.ago.to_date, end_date: Date.current) }

        context 'with PRs approved at different times' do
          let!(:fresh_pr) do
            create(:pull_request, :approved_days_ago, days_ago: 5,
                                                      repository: repository, gh_created_at: 60.days.ago)
          end
          let!(:late_pr1) do
            create(:pull_request, :approved_days_ago, days_ago: 10,
                                                      repository: repository, gh_created_at: 60.days.ago)
          end
          let!(:late_pr2) do
            create(:pull_request, :approved_days_ago, days_ago: 27,
                                                      repository: repository, gh_created_at: 60.days.ago)
          end
          let!(:stale_pr) do
            create(:pull_request, :approved_days_ago, days_ago: 40,
                                                      repository: repository, gh_created_at: 60.days.ago)
          end

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
            pr = create(:pull_request, :approved_before_week_end,
                        repository: repository, week: week, days_before_week_end: 7)
            expect(week.late_prs).not_to include(pr)
          end

          it 'PR approved exactly 8 days before week end IS late' do
            pr = create(:pull_request, :approved_before_week_end,
                        repository: repository, week: week, days_before_week_end: 8)
            expect(week.late_prs).to include(pr)
          end

          it 'PR approved exactly 27 days before week end IS still late' do
            pr = create(:pull_request, :approved_before_week_end,
                        repository: repository, week: week, days_before_week_end: 27)
            expect(week.late_prs).to include(pr)
          end

          it 'PR approved exactly 28 days before week end IS stale (not late)' do
            pr = create(:pull_request, :approved_before_week_end,
                        repository: repository, week: week, days_before_week_end: 28)

            # Should be in stale_prs and NOT in late_prs
            expect(week.stale_prs).to contain_exactly(pr)
            expect(week.late_prs).to be_empty
          end
        end

        context 'with merged PRs' do
          it 'excludes merged PRs from late_prs even if approved long ago' do
            merged_pr = create(:pull_request, :approved_before_week_end,
                               repository: repository, week: week, days_before_week_end: 15,
                               gh_merged_at: 5.days.ago)

            expect(week.late_prs).not_to include(merged_pr)
          end

          it 'excludes merged PRs from stale_prs even if approved long ago' do
            merged_pr = create(:pull_request, :approved_before_week_end,
                               repository: repository, week: week, days_before_week_end: 35,
                               gh_merged_at: 5.days.ago)

            expect(week.stale_prs).not_to include(merged_pr)
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
