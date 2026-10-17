require 'rails_helper'

RSpec.describe Tracker do
  describe 'associations' do
    it { is_expected.to belong_to(:source_repository).class_name('Repository').optional }
    it { is_expected.to have_many(:repositories).dependent(:nullify) }
    it { is_expected.to have_many(:stories).dependent(:destroy) }
  end

  describe 'a GitHub issues tracker' do
    subject(:tracker) { build(:tracker, source_repository: nil) }

    it 'needs the repository whose issues it reads' do
      expect(tracker).not_to be_valid
      expect(tracker.errors[:source_repository]).to include("can't be blank")
    end
  end

  describe 'one tracker per source repository' do
    subject(:tracker) { create(:tracker) }

    it { is_expected.to validate_uniqueness_of(:source_repository_id).allow_nil }
  end
end
