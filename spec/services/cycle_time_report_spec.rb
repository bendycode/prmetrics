require 'rails_helper'

RSpec.describe CycleTimeReport do
  let(:tracker) { create(:tracker) }
  let(:day0) { Time.zone.parse('2026-09-01 10:00') }

  # Days of 24 hours: cycle time is elapsed time, and day0 + 85.days would
  # cross a clock change and be an hour longer
  def finished(days, committed_source: :opened, started_source: :assigned, **attributes)
    create(:story, tracker: tracker, committed_at: day0, committed_source: committed_source,
                   started_at: day0, started_source: started_source, done_at: day0 + (days * 24).hours, **attributes)
  end

  def report(clock = :committed)
    described_class.new(tracker, clock: clock)
  end

  describe 'percentiles, by the nearest-rank method' do
    it 'reports the one story of a single-story tracker as both' do
      finished(3)

      expect(report).to have_attributes(median_days: 3.0, p85_days: 3.0)
    end

    it 'takes the lower of two stories as the median and the higher as the 85th percentile' do
      finished(2)
      finished(6)

      expect(report).to have_attributes(median_days: 2.0, p85_days: 6.0)
    end

    it 'takes the 10th and 17th of twenty stories' do
      (1..20).to_a.reverse_each { |days| finished(days) }

      expect(report).to have_attributes(median_days: 10.0, p85_days: 17.0)
    end

    it 'reports neither when no story is finished' do
      create(:story, tracker: tracker)

      expect(report).to have_attributes(stories: [], median_days: nil, p85_days: nil)
    end
  end

  describe 'the stories measured' do
    it 'measures the chosen clock from its own start' do
      finished(4, started_at: day0 + 24.hours)

      expect([report(:committed).median_days, report(:started).median_days]).to eq([4.0, 3.0])
    end

    it 'leaves out a story GitHub no longer has' do
      finished(4, gone: true)

      expect(report.stories).to be_empty
    end

    it 'leaves out a story with no start from the started clock only' do
      story = finished(4, started_at: nil, started_source: nil)

      expect([report(:committed).stories, report(:started).stories]).to eq([[story], []])
    end

    it 'orders the stories by when they were done' do
      later = finished(5)
      sooner = finished(2)

      expect(report.stories).to eq([sooner, later])
    end
  end

  describe '#coverage' do
    it 'counts how each clock\'s stories got their start' do
      finished(1)
      finished(2, committed_source: :commit_referenced, started_source: :commit_referenced)
      finished(3, started_source: :pull_request_linked)
      finished(4, started_at: nil, started_source: nil)

      expect([report(:committed).coverage, report(:started).coverage])
        .to eq([{ trigger: 3, fallback: 1, missing: 0 }, { trigger: 1, fallback: 2, missing: 1 }])
    end
  end
end
