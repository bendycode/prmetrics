require 'rails_helper'

RSpec.describe PullRequest, type: :model do
  let(:repository) { create(:repository) }
  let(:author) { create :github_user }
  let(:contributor) { create(:contributor) }

  describe 'weekday hours calculation' do
    let(:pull_request) do
      create(:pull_request,
        repository: repository,
        author: author,
        ready_for_review_at: Time.zone.local(2024, 1, 8, 9, 0, 0) # Monday 9 AM
      )
    end

    context 'with time_to_first_review' do
      it 'calculates weekday hours correctly for same day review' do
        review = create(:review,
          pull_request: pull_request,
          author: contributor,
          submitted_at: Time.zone.local(2024, 1, 8, 17, 0, 0), # Monday 5 PM
          state: 'approved'
        )

        # From Monday 9am to Monday 5pm = 8 hours
        expect(pull_request.time_to_first_review).to eq(8.hours)
        expect(pull_request.raw_time_to_first_review).to eq(8.to_f)
      end

      it 'excludes weekend hours for review spanning a weekend' do
        review = create(:review,
          pull_request: pull_request,
          author: contributor,
          submitted_at: Time.zone.local(2024, 1, 15, 13, 0, 0), # Next Monday 1 PM
          state: 'approved'
        )

        # Raw time would include weekend hours
        # From Monday 9am to next Monday 1pm = (7*24 + 4) = 172 hours
        expect(pull_request.raw_time_to_first_review).to be_within(0.1).of(172.0)

        # Weekday hours calculation (Monday 9-midnight = 15, Tuesday-Friday 24*4 = 96, Monday midnight-1pm = 13)
        # (15 + 96 + 13 = 124 hours)
        expect(pull_request.time_to_first_review).to be_within(0.1).of(124.hours)
      end

      it 'handles PR created on weekend, reviewed on weekday' do
        weekend_pr = create(:pull_request,
          repository: repository,
          author: author,
          ready_for_review_at: Time.zone.local(2024, 1, 6, 10, 0, 0) # Saturday 10 AM
        )

        review = create(:review,
          pull_request: weekend_pr,
          author: contributor,
          submitted_at: Time.zone.local(2024, 1, 8, 14, 0, 0), # Monday 2 PM
          state: 'approved'
        )

        # Raw time would be from Saturday 10am to Monday 2pm = 52 hours
        expect(weekend_pr.raw_time_to_first_review).to be_within(0.1).of(52.0)

        # Weekday hours should only count Monday 12am to 2pm = 14 hours
        expect(weekend_pr.time_to_first_review).to be_within(0.1).of(14.hours)
      end
    end

    context 'with weekday_hours_to_merge' do
      it 'calculates weekday hours correctly for same day merge' do
        pull_request.gh_merged_at = Time.zone.local(2024, 1, 8, 17, 0, 0) # Monday 5 PM

        # From Monday 9am to Monday 5pm = 8 hours
        expect(pull_request.weekday_hours_to_merge).to eq(8.hours)
      end

      it 'excludes weekend hours for merge spanning a weekend' do
        pull_request.gh_merged_at = Time.zone.local(2024, 1, 15, 13, 0, 0) # Next Monday 1 PM

        # Weekday hours calculation
        # (Monday 9-midnight = 15, Tuesday-Friday 24*4 = 96, Monday midnight-1pm = 13)
        # (15 + 96 + 13 = 124 hours)
        expect(pull_request.weekday_hours_to_merge).to be_within(0.1).of(124.hours)
      end

      it 'returns nil when ready_for_review_at is nil' do
        pull_request.ready_for_review_at = nil
        pull_request.gh_merged_at = Time.zone.local(2024, 1, 10, 14, 0, 0)

        expect(pull_request.weekday_hours_to_merge).to be_nil
      end

      it 'returns nil when gh_merged_at is nil' do
        pull_request.gh_merged_at = nil

        expect(pull_request.weekday_hours_to_merge).to be_nil
      end
    end
  end

  describe 'time_to_first_review behavior' do
    let(:user) { create(:user) }
    let(:pull_request) do
      create(:pull_request,
        repository: repository,
        author: author,
        ready_for_review_at: 1.day.ago
      )
    end

    it 'should return a positive duration for reviews submitted after ready_for_review_at' do
      # Use a Monday at 9 AM as ready_for_review_at
      monday_9am = 1.week.ago.beginning_of_week + 9.hours
      pull_request.update!(ready_for_review_at: monday_9am)
      
      # Review submitted 2 hours later on same Monday
      review = create(:review,
        pull_request: pull_request,
        author: contributor,
        submitted_at: monday_9am + 2.hours,
        state: 'approved'
      )

      expect(pull_request.time_to_first_review).to be > 0.hours
    end

    it 'should return nil when all reviews are submitted before ready_for_review_at' do
      review = create(:review,
        pull_request: pull_request,
        author: contributor,
        submitted_at: 2.days.ago,
        state: 'approved'
      )

      # Should return nil as there are no valid reviews after ready_for_review_at
      expect(pull_request.time_to_first_review).to be_nil
    end

    it 'should ignore reviews submitted before ready_for_review_at when finding first review' do
      # Use a Monday at 9 AM as ready_for_review_at
      monday_9am = 1.week.ago.beginning_of_week + 9.hours
      pull_request.update!(ready_for_review_at: monday_9am)
      
      # Earlier invalid review (before ready_for_review_at)
      early_review = create(:review,
        pull_request: pull_request,
        author: contributor,
        submitted_at: monday_9am - 1.hour,
        state: 'approved'
      )

      # Later valid review - 3 hours after ready_for_review_at
      valid_review = create(:review,
        pull_request: pull_request,
        author: contributor,
        submitted_at: monday_9am + 3.hours,
        state: 'approved'
      )

      # Should use the valid review for calculation, which is > 0
      expect(pull_request.time_to_first_review).to be > 0.hours
      # Should specifically use the later review
      expect(pull_request.valid_first_review).to eq(valid_review)
    end

    it 'correctly sets first_review_week based on valid reviews only' do
      week = create(:week, repository: repository, begin_date: 1.week.ago, end_date: Date.today)

      # Earlier invalid review
      early_review = create(:review,
        pull_request: pull_request,
        author: contributor,
        submitted_at: 2.days.ago,
        state: 'approved'
      )

      pull_request.update_week_associations
      expect(pull_request.first_review_week).to be_nil

      # Add a valid review
      valid_review = create(:review,
        pull_request: pull_request,
        author: contributor,
        submitted_at: 12.hours.ago,
        state: 'approved'
      )

      pull_request.update_week_associations
      expect(pull_request.first_review_week).to eq(week)
    end

    it 'returns nil for time_to_first_review when ready_for_review_at is nil' do
      pr_without_ready = create(:pull_request,
        repository: repository,
        author: author,
        ready_for_review_at: nil
      )

      review = create(:review,
        pull_request: pr_without_ready,
        author: contributor,
        submitted_at: Time.current,
        state: 'approved'
      )

      expect(pr_without_ready.time_to_first_review).to be_nil
    end
  end

  it "is valid with valid attributes" do
    pull_request = PullRequest.new(
      repository: repository,
      author: author,
      number: 1,
      title: "Test PR",
      state: "open",
      draft: false
    )
    expect(pull_request).to be_valid
  end

  it "is not valid without a repository" do
    pull_request = PullRequest.new(number: 1, title: "Test PR", state: "open")
    expect(pull_request).to_not be_valid
  end

  it "is not valid without a number" do
    pull_request = PullRequest.new(repository: repository, title: "Test PR", state: "open")
    expect(pull_request).to_not be_valid
  end

  it "validates uniqueness of number scoped to repository" do
    create(:pull_request, repository: repository, number: 123)
    duplicate = build(:pull_request, repository: repository, number: 123)
    expect(duplicate).to_not be_valid
    expect(duplicate.errors[:number]).to include("has already been taken")
  end

  it "allows same number in different repositories" do
    other_repository = create(:repository, name: "other/repo")
    create(:pull_request, repository: repository, number: 123)
    different_repo_pr = build(:pull_request, repository: other_repository, number: 123)
    expect(different_repo_pr).to be_valid
  end

  it "belongs to a repository" do
    association = described_class.reflect_on_association(:repository)
    expect(association.macro).to eq :belongs_to
  end

  it "has many reviews" do
    association = described_class.reflect_on_association(:reviews)
    expect(association.macro).to eq :has_many
  end

  it "has many pull request users" do
    association = described_class.reflect_on_association(:pull_request_users)
    expect(association.macro).to eq :has_many
  end

  it "has many contributors through pull request users" do
    association = described_class.reflect_on_association(:contributors)
    expect(association.macro).to eq :has_many
    expect(association.options[:through]).to eq :pull_request_users
  end
end
