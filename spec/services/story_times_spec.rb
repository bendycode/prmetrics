require 'rails_helper'

RSpec.describe StoryTimes do
  let(:day0) { Time.zone.parse('2026-09-01 10:00') }
  let(:triggers) { Tracker::KINDS.fetch('github_issues')[:triggers] }

  def event(kind, day, payload = {})
    StoryEvent.new(kind: kind, occurred_at: day0 + day.days, payload: payload)
  end

  def times(events, state_reason: 'completed')
    described_class.new(events: events, triggers: triggers, state_reason: state_reason)
  end

  describe 'started' do
    it 'takes the earliest matching event, whichever kind it is' do
      result = times([event(:opened, 0), event(:assigned, 5), event(:commit_referenced, 2), event(:closed, 9)])

      expect(result).to have_attributes(started_at: day0 + 2.days, started_source: :commit_referenced)
    end

    it 'falls back to a pull request link when nothing else started the work' do
      result = times([event(:opened, 0), event(:pull_request_linked, 3), event(:closed, 6)])

      expect(result).to have_attributes(started_at: day0 + 3.days, started_source: :pull_request_linked)
    end

    it 'is unknown when no event started the work' do
      result = times([event(:opened, 0), event(:closed, 4)])

      expect(result).to have_attributes(started_at: nil, started_source: nil)
    end

    it 'ignores events after the work was done' do
      result = times([event(:opened, 0), event(:closed, 4), event(:commit_referenced, 5)])

      expect(result).to have_attributes(started_at: nil, started_source: nil)
    end
  end

  describe 'committed' do
    it 'is when the story was opened' do
      result = times([event(:opened, 1), event(:assigned, 3), event(:closed, 4)])

      expect(result).to have_attributes(committed_at: day0 + 1.day, committed_source: :opened)
    end

    it 'moves back to the started time when the work started before it was committed to' do
      result = times([event(:commit_referenced, 1), event(:opened, 2), event(:closed, 4)])

      expect(result).to have_attributes(committed_at: day0 + 1.day, committed_source: :commit_referenced)
    end
  end

  describe 'done' do
    it 'is the close of a story closed as completed' do
      expect(times([event(:opened, 0), event(:closed, 4)]).done_at).to eq(day0 + 4.days)
    end

    it 'is the last close when the story was reopened and closed again' do
      result = times([event(:opened, 0), event(:closed, 2), event(:reopened, 3), event(:closed, 6)])

      expect(result.done_at).to eq(day0 + 6.days)
    end

    # Read from the events alone: the issue's reason is left at completed.
    it 'is not reached while a reopened story is still open' do
      result = times([event(:opened, 0), event(:closed, 2), event(:reopened, 3)])

      expect(result.done_at).to be_nil
    end

    it 'is never reached by a story closed as not planned' do
      expect(times([event(:opened, 0), event(:closed, 4)], state_reason: 'not_planned').done_at).to be_nil
    end

    it 'is never reached by a story closed as a duplicate' do
      expect(times([event(:opened, 0), event(:closed, 4)], state_reason: 'duplicate').done_at).to be_nil
    end

    # GitHub records no reason on issues closed before it began recording them
    it 'is reached by a close GitHub recorded no reason for' do
      expect(times([event(:opened, 0), event(:closed, 4)], state_reason: nil).done_at).to eq(day0 + 4.days)
    end

    it 'counts events that arrive in any order' do
      result = times([event(:closed, 6), event(:reopened, 3), event(:closed, 2), event(:opened, 0)])

      expect(result.done_at).to eq(day0 + 6.days)
    end
  end

  describe 'triggers with conditions on the payload' do
    let(:triggers) do
      { committed: [StoryTrigger[:opened]],
        started: [StoryTrigger[:assigned, 'assignee' => { 'type' => 'User' }]],
        done: { close: [StoryTrigger[:closed]], reopen: [StoryTrigger[:reopened]] } }
    end

    it 'starts at the first event whose payload matches' do
      result = times([event(:opened, 0), event(:assigned, 1, 'assignee' => { 'type' => 'Bot' }),
                      event(:assigned, 3, 'assignee' => { 'type' => 'User' }), event(:closed, 5)])

      expect(result).to have_attributes(started_at: day0 + 3.days, started_source: :assigned)
    end
  end

  describe 'done rules' do
    let(:triggers) do
      { committed: [StoryTrigger[:opened]], started: [StoryTrigger[:assigned]],
        done: { close: [StoryTrigger[:pull_request_linked]], reopen: [StoryTrigger[:commit_referenced]] } }
    end

    it 'closes and reopens on the events the tracker kind names' do
      result = times([event(:opened, 0), event(:pull_request_linked, 2), event(:commit_referenced, 3),
                      event(:pull_request_linked, 5), event(:closed, 6)])

      expect(result.done_at).to eq(day0 + 5.days)
    end

    it 'is not reached while the kind\'s reopen is the last word' do
      result = times([event(:opened, 0), event(:pull_request_linked, 2), event(:commit_referenced, 3), event(:closed, 4)])

      expect(result.done_at).to be_nil
    end
  end
end
