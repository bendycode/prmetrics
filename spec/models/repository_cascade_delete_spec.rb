require 'rails_helper'

RSpec.describe 'Repository cascade delete', type: :model do
  let(:repository) { create(:repository) }
  let(:github_user1) { create(:github_user) }
  let(:github_user2) { create(:github_user) }
  let(:user1) { create(:user) }
  let(:user2) { create(:user) }
  
  before do
    # Create pull requests with different authors
    @pr1 = create(:pull_request, repository: repository, author: github_user1)
    @pr2 = create(:pull_request, repository: repository, author: github_user1)
    @pr3 = create(:pull_request, repository: repository, author: github_user2)
    
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
    
    it 'does not delete User records (reviewers)' do
      expect { repository.destroy }.not_to change { User.count }
      expect(User.where(id: [user1.id, user2.id])).to exist
    end
    
    it 'deletes GithubUser records that have no other pull requests' do
      # Create another repository with a PR by github_user1
      other_repo = create(:repository)
      other_pr = create(:pull_request, repository: other_repo, author: github_user1)
      
      expect { repository.destroy }.to change { GithubUser.count }.by(-1)
      
      # github_user2 should be deleted (only had PRs in deleted repo)
      expect(GithubUser.find_by(id: github_user2.id)).to be_nil
      
      # github_user1 should still exist (has PR in other repo)
      expect(GithubUser.find_by(id: github_user1.id)).to be_present
    end
    
    it 'handles repositories with no associations gracefully' do
      empty_repo = create(:repository)
      expect { empty_repo.destroy }.not_to raise_error
      expect(Repository.find_by(id: empty_repo.id)).to be_nil
    end
  end
  
  describe 'orphaned GithubUser cleanup' do
    it 'deletes GithubUser when their last pull request is deleted individually' do
      # Delete all PRs for github_user2 except one
      @pr1.destroy
      @pr2.destroy
      
      expect(GithubUser.find_by(id: github_user2.id)).to be_present
      
      # Delete the last PR
      expect { @pr3.destroy }.to change { GithubUser.count }.by(-1)
      expect(GithubUser.find_by(id: github_user2.id)).to be_nil
    end
    
    it 'keeps GithubUser when they still have other pull requests' do
      @pr1.destroy
      
      expect(GithubUser.find_by(id: github_user1.id)).to be_present
      expect(github_user1.authored_pull_requests.count).to eq(1)
    end
  end
end