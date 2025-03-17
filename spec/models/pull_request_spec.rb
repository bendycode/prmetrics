require 'rails_helper'

RSpec.describe PullRequest, type: :model do
  let(:repository) { Repository.create(name: "Test Repo", url: "https://github.com/test/repo") }
  let(:author) { create :github_user }

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
      review = create(:review,
        pull_request: pull_request,
        author: user,
        submitted_at: Time.current,
        state: 'approved'
      )

      expect(pull_request.time_to_first_review).to be > 0
    end

    it 'should return nil when all reviews are submitted before ready_for_review_at' do
      review = create(:review,
        pull_request: pull_request,
        author: user,
        submitted_at: 2.days.ago,
        state: 'approved'
      )

      # Should return nil as there are no valid reviews after ready_for_review_at
      expect(pull_request.time_to_first_review).to be_nil
    end

    it 'should ignore reviews submitted before ready_for_review_at when finding first review' do
      # Earlier invalid review
      early_review = create(:review,
        pull_request: pull_request,
        author: user,
        submitted_at: 2.days.ago,
        state: 'approved'
      )

      # Later valid review
      valid_review = create(:review,
        pull_request: pull_request,
        author: user,
        submitted_at: 12.hours.ago,
        state: 'approved'
      )

      # Should use the valid review for calculation
      expect(pull_request.time_to_first_review).to be > 0
      expect(pull_request.time_to_first_review).to eq(valid_review.submitted_at - pull_request.ready_for_review_at)
    end

    it 'correctly sets first_review_week based on valid reviews only' do
      week = create(:week, repository: repository, begin_date: 1.week.ago, end_date: Date.today)

      # Earlier invalid review
      early_review = create(:review,
        pull_request: pull_request,
        author: user,
        submitted_at: 2.days.ago,
        state: 'approved'
      )

      pull_request.update_week_associations
      expect(pull_request.first_review_week).to be_nil

      # Add a valid review
      valid_review = create(:review,
        pull_request: pull_request,
        author: user,
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
        author: user,
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

  it "has many users through pull request users" do
    association = described_class.reflect_on_association(:users)
    expect(association.macro).to eq :has_many
    expect(association.options[:through]).to eq :pull_request_users
  end
end
