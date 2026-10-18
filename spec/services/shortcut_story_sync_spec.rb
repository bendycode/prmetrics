require 'rails_helper'

RSpec.describe ShortcutStorySync do
  let(:tracker) { create(:tracker, :shortcut, workflow_id: '100') }
  let(:shortcut) { instance_double(ShortcutService) }
  let(:sync) { described_class.new(tracker, shortcut: shortcut) }

  # A fixture history told about another story, as Shortcut would tell it
  def history_for(story_id, name = 'history_7001')
    JSON.parse(shortcut_json(name).gsub('7001', story_id.to_s))
  end

  before do
    allow(shortcut).to receive(:workflow).with('100').and_return(shortcut_fixture('workflow'))
    allow(shortcut).to receive(:stories_in_state).and_return([])
    allow(shortcut).to receive(:stories_in_state).with(105).and_return(shortcut_fixture('search_state_105'))
    allow(shortcut).to receive(:stories_in_state).with(103).and_return(shortcut_fixture('search_state_103'))
    allow(shortcut).to receive(:history).with(7001).and_return(shortcut_fixture('history_7001'))
    allow(shortcut).to receive(:history).with(7002).and_return(history_for(7002))
    allow(shortcut).to receive(:history).with(7003).and_return(history_for(7003).first(5))
  end

  it 'stores every story in the workflow, keyed sc-NNNN, open or closed by the type of state it is in' do
    sync.sync!

    expect(tracker.stories.order(:external_id).pluck(:external_id, :key, :state, :state_reason)).to eq(
      [%w[7001 sc-7001 closed] + [nil], %w[7002 sc-7002 closed archived], %w[7003 sc-7003 open] + [nil]]
    )
    expect(tracker.stories.find_by(external_id: '7001'))
      .to have_attributes(title: 'Story 7001', url: 'https://app.shortcut.com/example/story/7001')
  end

  it 'measures each story from its history' do
    sync.sync!

    expect(tracker.stories.find_by(external_id: '7001')).to have_attributes(
      committed_at: Time.zone.parse('2026-09-03T15:00:00Z'), committed_source: 'status_changed',
      started_at: Time.zone.parse('2026-09-05T15:00:00Z'), done_at: Time.zone.parse('2026-09-12T16:00:00Z')
    )
  end

  it 'leaves an archived story out of the finished stories' do
    sync.sync!

    expect(tracker.stories.finished.pluck(:external_id)).to eq(['7001'])
  end

  it 'skips the history of a story stored at the update Shortcut lists, once listed after it' do
    sync.sync!

    described_class.new(tracker, shortcut: shortcut).sync!

    expect(shortcut).to have_received(:history).with(7001).once
  end

  it 'reads a changed story again, storing each event once' do
    sync.sync!
    moved = shortcut_fixture('search_state_105').map { |story| story.merge('updated_at' => '2026-10-02T16:00:00Z') }
    allow(shortcut).to receive(:stories_in_state).with(105).and_return(moved)

    expect { described_class.new(tracker, shortcut: shortcut).sync! }.not_to change(StoryEvent, :count)
    expect(shortcut).to have_received(:history).with(7001).twice
  end

  it 'stores the other stories when one cannot be read, then reports it' do
    allow(shortcut).to receive(:history).with(7002).and_raise(ShortcutService::Error, 'Shortcut answered 500')

    expect { sync.sync! }.to raise_error(described_class::StoriesFailed, /sc-7002/)
    expect(tracker.stories.pluck(:external_id)).to contain_exactly('7001', '7003')
  end

  # Each request already retried for two minutes; an outage would otherwise cost that per story
  it 'stops after three stories in a row cannot be read' do
    many = (1..6).map { |n| shortcut_fixture('story_7001').merge('id' => 7100 + n) }
    allow(shortcut).to receive(:stories_in_state).with(105).and_return(many)
    allow(shortcut).to receive(:stories_in_state).with(103).and_return([])
    allow(shortcut).to receive(:history).and_raise(ShortcutService::Error, 'Shortcut answered 503')

    expect { sync.sync! }.to raise_error(described_class::StoriesFailed, /stopped after 3 failures in a row/)
    expect(shortcut).to have_received(:history).exactly(3).times
  end

  it 'logs a failure by story key and error class, never the message' do
    allow(Rails.logger).to receive(:error)
    allow(shortcut).to receive(:history).with(7002).and_raise(ShortcutService::Error, 'Shortcut answered 500 to GET x')

    expect { sync.sync! }.to raise_error(described_class::StoriesFailed)
    expect(Rails.logger).to have_received(:error).with('Story sync could not store story sc-7002: ShortcutService::Error')
  end
end
