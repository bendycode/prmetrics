require 'rails_helper'

RSpec.describe 'Repository cascade delete' do
  let(:repository) { create(:repository) }
  let(:contributor1) { create(:contributor) }
  let(:contributor2) { create(:contributor) }
  let(:user1) { create(:contributor, github_id: 'user_1') }
  let(:user2) { create(:contributor, github_id: 'user_2') }

  before do
    # Create pull requests with different authors
    @pr1 = create(:pull_request, repository: repository, author: contributor1)
    @pr2 = create(:pull_request, repository: repository, author: contributor1)
    @pr3 = create(:pull_request, repository: repository, author: contributor2)

    # Create reviews
    @review1 = create(:review, pull_request: @pr1, author: user1)
    @review2 = create(:review, pull_request: @pr1, author: user2)
    @review3 = create(:review, pull_request: @pr2, author: user1)
    @review4 = create(:review, pull_request: @pr3, author: user2)

    # Create pull request users
    @pru1 = create(:pull_request_user, pull_request: @pr1, user: user1)
    @pru2 = create(:pull_request_user, pull_request: @pr2, user: user2)

    # Create weeks
    @week1 = create(:week, repository: repository)
    @week2 = create(:week, repository: repository)

    # Associate PRs with weeks
    @pr1.update(ready_for_review_week: @week1, merged_week: @week2)
    @pr2.update(ready_for_review_week: @week1)
  end

  describe 'when repository is deleted' do
    it 'deletes all associated pull requests' do
      expect { repository.destroy }.to change { PullRequest.count }.by(-3)
      expect(PullRequest.where(id: [@pr1.id, @pr2.id, @pr3.id])).to be_empty
    end

    it 'deletes all associated reviews through pull requests' do
      expect { repository.destroy }.to change { Review.count }.by(-4)
      expect(Review.where(id: [@review1.id, @review2.id, @review3.id, @review4.id])).to be_empty
    end

    it 'deletes all associated pull_request_users' do
      expect { repository.destroy }.to change { PullRequestUser.count }.by(-2)
      expect(PullRequestUser.where(id: [@pru1.id, @pru2.id])).to be_empty
    end

    it 'deletes all associated weeks' do
      expect { repository.destroy }.to change { Week.count }.by(-2)
      expect(Week.where(id: [@week1.id, @week2.id])).to be_empty
    end

    it 'does not delete Contributor records (reviewers)' do
      # Contributors who only reviewed (user1, user2) should remain
      expect { repository.destroy }.not_to change {
        Contributor.where(id: [user1.id, user2.id]).count
      }
      expect(Contributor.where(id: [user1.id, user2.id])).to exist
    end

    it 'deletes Contributor records that have no other pull requests' do
      # Create another repository with a PR by contributor1
      other_repo = create(:repository)
      other_pr = create(:pull_request, repository: other_repo, author: contributor1)

      expect { repository.destroy }.to change { Contributor.count }.by(-1)

      # contributor2 should be deleted (only had PRs in deleted repo)
      expect(Contributor.find_by(id: contributor2.id)).to be_nil

      # contributor1 should still exist (has PR in other repo)
      expect(Contributor.find_by(id: contributor1.id)).to be_present
    end

    it 'handles repositories with no associations gracefully' do
      empty_repo = create(:repository)
      expect { empty_repo.destroy }.not_to raise_error
      expect(Repository.find_by(id: empty_repo.id)).to be_nil
    end
  end

  describe 'orphaned Contributor cleanup' do
    it 'deletes Contributor when their last pull request is deleted individually' do
      # Delete all PRs for contributor2 except one
      @pr1.destroy
      @pr2.destroy

      expect(Contributor.find_by(id: contributor2.id)).to be_present

      # Delete the last PR
      expect { @pr3.destroy }.to change { Contributor.count }.by(-1)
      expect(Contributor.find_by(id: contributor2.id)).to be_nil
    end

    it 'keeps Contributor when they still have other pull requests' do
      @pr1.destroy

      expect(Contributor.find_by(id: contributor1.id)).to be_present
      expect(contributor1.authored_pull_requests.count).to eq(1)
    end
  end
end