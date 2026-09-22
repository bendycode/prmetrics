require 'rails_helper'

RSpec.describe 'Dashboard averages' do
  let(:repository) { create(:repository) }
  let(:wednesday) { 2.weeks.ago.beginning_of_week + 2.days + 9.hours }

  before { sign_in create(:user, :admin) }

  it 'averages time to merge over merged pull requests only' do
    create(:pull_request, repository: repository, ready_for_review_at: wednesday, gh_merged_at: wednesday + 4.hours)
    create(:pull_request, repository: repository, ready_for_review_at: wednesday, gh_merged_at: nil)

    get dashboard_path

    expect(summary_card_value('Avg Time to Merge')).to eq('4.0')
  end

  it "averages time to first review from each pull request's earliest review" do
    slow = create(:pull_request, repository: repository, ready_for_review_at: wednesday)
    create(:review, pull_request: slow, submitted_at: wednesday + 6.hours)
    create(:review, pull_request: slow, submitted_at: wednesday + 2.hours)
    fast = create(:pull_request, repository: repository, ready_for_review_at: wednesday)
    create(:review, pull_request: fast, submitted_at: wednesday + 4.hours)
    create(:pull_request, repository: repository, ready_for_review_at: wednesday)

    get dashboard_path

    expect(summary_card_value('Avg Time to Review')).to eq('3.0')
  end

  describe 'with a promotion pull request' do
    before do
      create(:pull_request, repository: repository, ready_for_review_at: wednesday, gh_merged_at: wednesday + 4.hours)
      promotion = create(:pull_request, :promotion, repository: repository, ready_for_review_at: wednesday,
                                                    gh_merged_at: wednesday + 10.minutes)
      create(:review, pull_request: promotion, submitted_at: wednesday + 5.minutes)
    end

    it 'leaves it out of the pull request total and both averages' do
      get dashboard_path

      expect([summary_card_value('Total Pull Requests'), summary_card_value('Avg Time to Merge'),
              summary_card_value('Avg Time to Review')]).to eq(%w[1 4.0 0])
    end
  end

  it 'counts a Friday evening review in the configured time zone' do
    friday_afternoon = Time.zone.parse('2026-09-11 17:00')
    pull_request = create(:pull_request, repository: repository, ready_for_review_at: friday_afternoon)
    create(:review, pull_request: pull_request, submitted_at: friday_afternoon + 3.hours)

    get dashboard_path

    expect(summary_card_value('Avg Time to Review')).to eq('3.0')
  end
end
