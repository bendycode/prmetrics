require 'rails_helper'

RSpec.describe Story do
  describe 'associations' do
    it { is_expected.to belong_to(:tracker) }
    it { is_expected.to have_many(:events).class_name('StoryEvent').dependent(:delete_all) }
  end

  describe 'validations' do
    %i[key title url source_created_at source_updated_at listed_at].each do |attribute|
      it { is_expected.to validate_presence_of(attribute) }
    end

    it { is_expected.to validate_inclusion_of(:state).in_array(%w[open closed]) }
  end

  describe 'uniqueness of a story within its tracker' do
    subject(:story) { create(:story, external_id: 'a1b2c3') }

    it { is_expected.to validate_uniqueness_of(:external_id).scoped_to(:tracker_id) }

    it 'is enforced by the database when validation is skipped' do
      duplicate = build(:story, tracker: story.tracker, external_id: story.external_id)

      expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe '.listed_after_last_update' do
    let(:updated) { Time.zone.parse('2026-09-20 17:26:04') }

    it 'takes a story listed at least a minute after its update' do
      create(:story, external_id: '1', source_updated_at: updated, listed_at: updated + 59.seconds)
      listed_a_minute_later = create(:story, external_id: '2', source_updated_at: updated, listed_at: updated + 1.minute)

      expect(described_class.listed_after_last_update).to contain_exactly(listed_a_minute_later)
    end
  end

  describe '#record_events' do
    let(:story) { create(:story) }
    let(:attributes) do
      [{ external_id: '1', kind: :assigned, occurred_at: story.source_created_at, payload: { 'id' => 1 } },
       { external_id: 'opened', kind: :opened, occurred_at: story.source_created_at, payload: {} }]
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
