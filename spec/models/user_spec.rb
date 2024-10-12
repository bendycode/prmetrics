require 'rails_helper'

RSpec.describe User, type: :model do
  it "is valid with valid attributes" do
    user = User.new(username: "testuser", name: "Test User", email: "test@example.com")
    expect(user).to be_valid
  end

  it "is not valid without a username" do
    user = User.new(name: "Test User", email: "test@example.com")
    expect(user).to_not be_valid
  end

  it "has many pull request users" do
    association = described_class.reflect_on_association(:pull_request_users)
    expect(association.macro).to eq :has_many
  end

  it "has many pull requests through pull request users" do
    association = described_class.reflect_on_association(:pull_requests)
    expect(association.macro).to eq :has_many
    expect(association.options[:through]).to eq :pull_request_users
  end
end
