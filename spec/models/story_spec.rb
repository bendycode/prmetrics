require 'rails_helper'

RSpec.describe Story do
  describe 'associations' do
    it { is_expected.to belong_to(:tracker) }
    it { is_expected.to have_many(:events).class_name('StoryEvent').dependent(:delete_all) }
  end

  describe 'uniqueness of a story within its tracker' do
    subject(:story) { create(:story, external_id: 'a1b2c3') }

    it { is_expected.to validate_uniqueness_of(:external_id).scoped_to(:tracker_id) }

    it 'is enforced by the database when validation is skipped' do
      duplicate = build(:story, tracker: story.tracker, external_id: story.external_id)

      expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  it 'names the kind of event each time came from' do
    story = create(:story, committed_source: :opened, started_source: :commit_referenced)

    expect(story.reload).to have_attributes(committed_source: 'opened', started_source: 'commit_referenced')
  end
end
