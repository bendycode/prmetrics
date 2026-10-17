require 'rails_helper'

RSpec.describe StoryEvent do
  describe 'associations' do
    it { is_expected.to belong_to(:story) }
  end

  describe 'an event is stored once per story' do
    subject(:event) { create(:story_event, external_id: 'a1b2c3') }

    it { is_expected.to validate_uniqueness_of(:external_id).scoped_to(:story_id) }

    it 'is enforced by the database when validation is skipped' do
      duplicate = build(:story_event, story: event.story, external_id: event.external_id)

      expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
