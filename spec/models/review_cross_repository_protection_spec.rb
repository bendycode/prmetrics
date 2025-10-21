require 'rails_helper'

RSpec.describe Review do
  describe 'cross-repository week association protection' do
    let!(:repo1) { create(:repository, name: 'owner/repo1') }
    let!(:repo2) { create(:repository, name: 'owner/repo2') }

    let!(:week_repo1) { create(:week, repository: repo1, week_number: 202301, begin_date: Date.new(2023, 1, 2), end_date: Date.new(2023, 1, 8)) }
    let!(:week_repo2) { create(:week, repository: repo2, week_number: 202301, begin_date: Date.new(2023, 1, 2), end_date: Date.new(2023, 1, 8)) }

    let(:pr) { create(:pull_request, repository: repo1, ready_for_review_at: Date.new(2023, 1, 3).to_time) }
    let(:author) { create(:contributor) }

    describe 'automatic first review week assignment' do
      it 'assigns the first review week from the correct repository' do
        # Create a review that should trigger week assignment
        review = create(:review,
          pull_request: pr,
          author: author,
          submitted_at: Date.new(2023, 1, 5).to_time,
          state: 'APPROVED'
        )

        pr.reload
        expect(pr.first_review_week).to eq(week_repo1)
        expect(pr.first_review_week).not_to eq(week_repo2)
      end

      it 'does not assign a week from another repository even if date matches' do
        # Delete the week from repo1 so only repo2 has a week for this date
        week_repo1.destroy

        review = create(:review,
          pull_request: pr,
          author: author,
          submitted_at: Date.new(2023, 1, 5).to_time,
          state: 'APPROVED'
        )

        pr.reload
        # Should be nil because the PR's repository doesn't have a week for this date
        expect(pr.first_review_week).to be_nil
      end

      it 'updates first review week when earlier review is added' do
        # Create initial review
        later_review = create(:review,
          pull_request: pr,
          author: author,
          submitted_at: Date.new(2023, 1, 6).to_time,
          state: 'APPROVED'
        )

        pr.reload
        expect(pr.first_review_week).to eq(week_repo1)

        # Create earlier review
        earlier_review = create(:review,
          pull_request: pr,
          author: create(:contributor), # Different author
          submitted_at: Date.new(2023, 1, 4).to_time,
          state: 'COMMENTED'
        )

        pr.reload
        # Week should still be the same since both dates are in the same week
        expect(pr.first_review_week).to eq(week_repo1)
      end
    end
  end
end