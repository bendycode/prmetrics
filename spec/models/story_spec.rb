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

  describe '#record_events' do
    let(:story) { create(:story) }
    let(:attributes) do
      [{ external_id: '1', kind: :assigned, occurred_at: story.gh_created_at, payload: { 'id' => 1 } },
       { external_id: 'opened', kind: :opened, occurred_at: story.gh_created_at, payload: {} }]
    end

    it 'stores each event once however many reads have seen it' do
      story.record_events(attributes)

      expect { story.record_events(attributes) }.not_to(change { story.events.count })
    end

    it 'keeps each event\'s kind' do
      story.record_events(attributes)

      expect(story.events.order(:external_id).pluck(:kind)).to eq(%w[assigned opened])
    end

    it 'stores an event once when one read holds it twice' do
      expect { story.record_events([attributes.first, attributes.first]) }.to change { story.events.count }.by(1)
    end

    it 'adds the events a later read finds' do
      story.record_events(attributes.first(1))

      expect { story.record_events(attributes) }.to change { story.events.count }.from(1).to(2)
    end
  end
end
