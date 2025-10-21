require 'rails_helper'

RSpec.describe PullRequest do
  describe 'cross-repository week association protection' do
    let!(:repo1) { create(:repository, name: 'owner/repo1') }
    let!(:repo2) { create(:repository, name: 'owner/repo2') }

    let!(:week_repo1) do
      create(:week, repository: repo1, week_number: 202_301, begin_date: Date.new(2023, 1, 2),
                    end_date: Date.new(2023, 1, 8))
    end
    let!(:week_repo2) do
      create(:week, repository: repo2, week_number: 202_301, begin_date: Date.new(2023, 1, 2),
                    end_date: Date.new(2023, 1, 8))
    end

    let(:pr) { create(:pull_request, repository: repo1) }

    describe 'validation' do
      it 'prevents assigning a week from a different repository' do
        pr.merged_week = week_repo2
        expect(pr).not_to be_valid
        expect(pr.errors[:merged_week]).to include('must belong to the same repository as the pull request')
      end

      it 'allows assigning a week from the same repository' do
        pr.merged_week = week_repo1
        expect(pr).to be_valid
      end

      it 'validates all week associations' do
        pr.ready_for_review_week = week_repo2
        pr.first_review_week = week_repo2
        pr.merged_week = week_repo2
        pr.closed_week = week_repo2

        expect(pr).not_to be_valid
        expect(pr.errors[:ready_for_review_week]).to include('must belong to the same repository as the pull request')
        expect(pr.errors[:first_review_week]).to include('must belong to the same repository as the pull request')
        expect(pr.errors[:merged_week]).to include('must belong to the same repository as the pull request')
        expect(pr.errors[:closed_week]).to include('must belong to the same repository as the pull request')
      end
    end

    describe 'automatic week assignment' do
      it 'assigns weeks from the correct repository' do
        # Set dates that fall within our test weeks
        pr.ready_for_review_at = Date.new(2023, 1, 5).to_time
        pr.gh_merged_at = Date.new(2023, 1, 6).to_time
        pr.gh_closed_at = Date.new(2023, 1, 6).to_time

        pr.update_week_associations

        expect(pr.ready_for_review_week).to eq(week_repo1)
        expect(pr.merged_week).to eq(week_repo1)
        expect(pr.closed_week).to eq(week_repo1)

        # Ensure it didn't accidentally assign weeks from repo2
        expect(pr.ready_for_review_week).not_to eq(week_repo2)
        expect(pr.merged_week).not_to eq(week_repo2)
        expect(pr.closed_week).not_to eq(week_repo2)
      end

      it 'returns nil when no week exists for the repository' do
        # Create a PR for a date where only repo2 has a week
        create(:week, repository: repo2, week_number: 202_302,
                      begin_date: Date.new(2023, 1, 9),
                      end_date: Date.new(2023, 1, 15))

        pr.gh_merged_at = Date.new(2023, 1, 10).to_time
        pr.update_week_associations # This method doesn't create weeks

        # Should be nil because repo1 doesn't have a week for this date
        expect(pr.merged_week).to be_nil
      end

      it 'creates and assigns week when using ensure_weeks_exist_and_update_associations' do
        # Create a PR for a date where only repo2 has a week
        create(:week, repository: repo2, week_number: 202_302,
                      begin_date: Date.new(2023, 1, 9),
                      end_date: Date.new(2023, 1, 15))

        pr.gh_merged_at = Date.new(2023, 1, 10).to_time
        pr.ensure_weeks_exist_and_update_associations

        # Should create a week for repo1 and assign it
        expect(pr.merged_week).to be_present
        expect(pr.merged_week.repository).to eq(repo1)
        expect(pr.merged_week.week_number).to eq(202_302)
      end
    end

    describe 'Week.for_repository_and_week_number' do
      it 'returns existing week for the correct repository' do
        week = Week.for_repository_and_week_number(repo1, 202_301)
        expect(week).to eq(week_repo1)
        expect(week.repository).to eq(repo1)
      end

      it 'creates a new week if it does not exist for the repository' do
        expect do
          week = Week.for_repository_and_week_number(repo1, 202_302)
          expect(week.repository).to eq(repo1)
          expect(week.week_number).to eq(202_302)
        end.to change { repo1.weeks.count }.by(1)
      end

      it 'does not return weeks from other repositories' do
        week = Week.for_repository_and_week_number(repo1, 202_301)
        expect(week).not_to eq(week_repo2)
      end
    end
  end
end
