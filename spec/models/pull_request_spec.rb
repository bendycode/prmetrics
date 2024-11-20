require 'rails_helper'

RSpec.describe PullRequest, type: :model do
  let(:repository) { Repository.create(name: "Test Repo", url: "https://github.com/test/repo") }
  let(:author) { create :github_user }

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
