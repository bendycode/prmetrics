require 'rails_helper'

RSpec.describe Repository, type: :model do
  it "is valid with valid attributes" do
    repository = Repository.new(name: "Test Repo", url: "https://github.com/test/repo")
    expect(repository).to be_valid
  end

  it "is not valid without a name" do
    repository = Repository.new(url: "https://github.com/test/repo")
    expect(repository).to_not be_valid
  end

  it "is not valid without a url" do
    repository = Repository.new(name: "Test Repo")
    expect(repository).to_not be_valid
  end

  it "has many pull requests" do
    association = described_class.reflect_on_association(:pull_requests)
    expect(association.macro).to eq :has_many
  end
end
