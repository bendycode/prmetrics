require 'rails_helper'

RSpec.describe Review, type: :model do
  let(:repository) { Repository.create(name: "Test Repo", url: "https://github.com/test/repo") }
  let(:pull_request) { create :pull_request }
  let(:author) { create :user }

  it "is valid with valid attributes" do
    review = Review.new(pull_request: pull_request, state: "approved", submitted_at: Time.current, author: author)
    expect(review).to be_valid
  end

  it "is not valid without a pull request" do
    review = Review.new(state: "approved", submitted_at: Time.current)
    expect(review).to_not be_valid
  end

  it "is not valid without a state" do
    review = Review.new(pull_request: pull_request, submitted_at: Time.current)
    expect(review).to_not be_valid
  end

  it "belongs to a pull request" do
    association = described_class.reflect_on_association(:pull_request)
    expect(association.macro).to eq :belongs_to
  end
end
