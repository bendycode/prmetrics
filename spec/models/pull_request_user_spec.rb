require 'rails_helper'

RSpec.describe PullRequestUser, type: :model do
  let(:repository) { Repository.create(name: "Test Repo", url: "https://github.com/test/repo") }
  let(:pull_request) { PullRequest.create(repository: repository, number: 1, title: "Test PR", state: "open", gh_created_at: Time.now, gh_updated_at: Time.now) }
  let(:user) { User.create(username: "testuser", name: "Test User", email: "test@example.com") }

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

  it "belongs to a pull request" do
    association = described_class.reflect_on_association(:pull_request)
    expect(association.macro).to eq :belongs_to
  end

  it "belongs to a user" do
    association = described_class.reflect_on_association(:user)
    expect(association.macro).to eq :belongs_to
  end
end
