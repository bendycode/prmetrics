require 'rails_helper'

RSpec.describe Tracker do
  describe 'associations' do
    it { is_expected.to belong_to(:source_repository).class_name('Repository').optional }
    it { is_expected.to have_many(:repositories).dependent(:nullify) }
    it { is_expected.to have_many(:stories).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:tracker) }

    it { is_expected.to validate_presence_of(:source_repository) }
    it { is_expected.to validate_presence_of(:kind) }
    it { is_expected.to allow_value('PRM', 'A1').for(:key_prefix) }
    it { is_expected.not_to allow_value('prm', 'PRM-', 'P M').for(:key_prefix) }
  end

  describe '#story_key' do
    it 'uses the project\'s key prefix' do
      expect(build(:tracker, key_prefix: 'PRM').story_key(79)).to eq('PRM-79')
    end

    it 'falls back to GitHub\'s number without one' do
      expect(build(:tracker).story_key(79)).to eq('#79')
    end
  end

  describe 'one tracker per source repository' do
    subject(:tracker) { create(:tracker) }

    it { is_expected.to validate_uniqueness_of(:source_repository_id).allow_nil }
  end
end
