require 'rails_helper'

RSpec.describe StoryTimes do
  let(:day0) { Time.zone.parse('2026-09-01 10:00') }
  let(:triggers) { { committed: %i[opened], started: %i[assigned commit_referenced pull_request_linked] } }

  def event(kind, day)
    StoryEvent.new(kind: kind, occurred_at: day0 + day.days)
  end

  def times(events, state_reason: 'completed')
    described_class.new(events: events, triggers: triggers, state_reason: state_reason)
  end

  describe 'started' do
    it 'takes the earliest matching event, whichever kind it is' do
      result = times([event(:opened, 0), event(:assigned, 5), event(:commit_referenced, 2), event(:closed, 9)])

      expect([result.started_at, result.started_source]).to eq([day0 + 2.days, :commit_referenced])
    end

    it 'falls back to a pull request link when nothing else started the work' do
      result = times([event(:opened, 0), event(:pull_request_linked, 3), event(:closed, 6)])

      expect([result.started_at, result.started_source]).to eq([day0 + 3.days, :pull_request_linked])
    end

    it 'is unknown when no event started the work' do
      result = times([event(:opened, 0), event(:closed, 4)])

      expect([result.started_at, result.started_source]).to eq([nil, nil])
    end

    it 'ignores events after the work was done' do
      result = times([event(:opened, 0), event(:closed, 4), event(:commit_referenced, 5)])

      expect(result).to have_attributes(started_at: nil, started_source: nil)
    end
  end

  describe 'committed' do
    it 'is when the story was opened' do
      result = times([event(:opened, 1), event(:assigned, 3), event(:closed, 4)])

      expect([result.committed_at, result.committed_source]).to eq([day0 + 1.day, :opened])
    end

    it 'moves back to the started time when the work started before it was committed to' do
      result = times([event(:commit_referenced, 1), event(:opened, 2), event(:closed, 4)])

      expect([result.committed_at, result.committed_source]).to eq([day0 + 1.day, :commit_referenced])
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
end
