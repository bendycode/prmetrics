require 'rails_helper'

RSpec.describe PullRequestUser, type: :model do
  let(:repository) { create(:repository) }
  let(:author) { create(:contributor) }
  let(:pull_request) { create(:pull_request, repository: repository, author: author) }
  let(:user) { create(:contributor) }

  it "is valid with valid attributes" do
    pull_request_user = PullRequestUser.new(pull_request: pull_request, user: user, role: "author")
    expect(pull_request_user).to be_valid
  end

  it "is not valid without a pull request" do
    pull_request_user = PullRequestUser.new(user: user, role: "author")
    expect(pull_request_user).to_not be_valid
  end

  it "is not valid without a user" do
    pull_request_user = PullRequestUser.new(pull_request: pull_request, role: "author")
    expect(pull_request_user).to_not be_valid
  end

  it "is not valid without a role" do
    pull_request_user = PullRequestUser.new(pull_request: pull_request, user: user)
    expect(pull_request_user).to_not be_valid
  end

  it "validates uniqueness of user scoped to pull_request and role" do
    PullRequestUser.create!(pull_request: pull_request, user: user, role: "reviewer")
    duplicate = PullRequestUser.new(pull_request: pull_request, user: user, role: "reviewer")
    expect(duplicate).to_not be_valid
    expect(duplicate.errors[:user_id]).to include("has already been taken")
  end

  it "allows same user with different role on same pull request" do
    PullRequestUser.create!(pull_request: pull_request, user: user, role: "reviewer")
    different_role = PullRequestUser.new(pull_request: pull_request, user: user, role: "assignee")
    expect(different_role).to be_valid
  end

  it "allows same user with same role on different pull requests" do
    other_pr = create(:pull_request, repository: repository, author: author, number: 2)
    PullRequestUser.create!(pull_request: pull_request, user: user, role: "reviewer")
    different_pr = PullRequestUser.new(pull_request: other_pr, user: user, role: "reviewer")
    expect(different_pr).to be_valid
  end

  it "belongs to a pull request" do
    association = described_class.reflect_on_association(:pull_request)
    expect(association.macro).to eq :belongs_to
  end

  it "belongs to a contributor" do
    association = described_class.reflect_on_association(:user)
    expect(association.macro).to eq :belongs_to
    expect(association.options[:class_name]).to eq 'Contributor'
  end
end
