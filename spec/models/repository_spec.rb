require 'rails_helper'

RSpec.describe Repository, type: :model do
  it "is valid with valid attributes" do
    repository = Repository.new(name: "test/repo", url: "https://github.com/test/repo")
    expect(repository).to be_valid
  end

  it "is not valid without a name" do
    repository = Repository.new(url: "https://github.com/test/repo")
    expect(repository).to_not be_valid
  end

  it "auto-generates url when not provided" do
    repository = Repository.new(name: "test/repo")
    expect(repository).to be_valid
    expect(repository.url).to eq("https://github.com/test/repo")
  end
  
  it "validates repository name format" do
    repository = Repository.new(name: "invalid-name", url: "https://github.com/test/repo")
    expect(repository).to_not be_valid
    expect(repository.errors[:name]).to include("must be in format 'owner/repository'")
  end
  
  it "accepts valid repository name formats" do
    valid_names = ["owner/repo", "some-org/my-repo", "user123/test.project"]
    valid_names.each do |name|
      repository = Repository.new(name: name, url: "https://github.com/#{name}")
      expect(repository).to be_valid, "Expected #{name} to be valid"
    end
  end
  
  
  it "enforces uniqueness of name" do
    create(:repository, name: "rails/rails")
    duplicate = Repository.new(name: "rails/rails", url: "https://github.com/rails/rails")
    expect(duplicate).to_not be_valid
    expect(duplicate.errors[:name]).to include("has already been taken")
  end

  it "has many pull requests" do
    association = described_class.reflect_on_association(:pull_requests)
    expect(association.macro).to eq :has_many
  end
end
