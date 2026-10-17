require 'rails_helper'

RSpec.describe GithubIssueTimeline do
  def events_for(name)
    fixture = github_issue_fixture(name)
    described_class.new(repo_name: 'bendycode/prmetrics', issue: fixture[:issue], timeline: fixture[:timeline]).events
  end

  describe 'a finished issue with assignments, commits, and pull requests' do
    subject(:events) { events_for('issue_79') }

    it 'keeps the events cycle time is measured from, in kinds that mean the same across trackers' do
      expect(events.pluck(:kind).tally)
        .to eq(opened: 1, assigned: 1, commit_referenced: 5, pull_request_linked: 4, closed: 1)
    end

    it 'records the opening, which GitHub keeps on the issue rather than its timeline' do
      opened = events.find { |event| event[:kind] == :opened }

      expect(opened).to include(occurred_at: Time.zone.parse('2026-09-17T09:57:04Z'))
    end

    it 'links only pull requests, leaving out issues that mention this one' do
      linked = events.select { |event| event[:kind] == :pull_request_linked }

      expect(linked.map { |event| event[:payload]['source']['issue']['number'] }).to eq([86, 87, 88, 89])
    end

    it 'keeps GitHub\'s own ID where the event has one' do
      assigned = events.find { |event| event[:kind] == :assigned }

      expect(assigned[:external_id]).to eq('31312719938')
    end

    it 'gives every event an ID of its own' do
      expect(events.pluck(:external_id).uniq.size).to eq(events.size)
    end
  end

  it 'keeps a reopening between two closes' do
    expect(events_for('issue_reopened').pluck(:kind)).to eq(%i[opened assigned closed reopened closed])
  end

  it 'leaves out a pull request or a commit from another repository' do
    expect(events_for('issue_mention_only').pluck(:kind)).to eq(%i[opened closed])
  end

  it 'leaves out an event GitHub sent without a time' do
    fixture = github_issue_fixture('issue_not_planned')
    timeline = [github_resource(event: 'assigned', id: 1), *fixture.timeline]
    events = described_class.new(repo_name: 'bendycode/prmetrics', issue: fixture.issue, timeline: timeline).events

    expect(events.pluck(:external_id)).to eq(%w[opened 5 6])
  end

  # The app stores a repository's name as typed; GitHub's URLs carry its own case
  it 'counts a commit and a pull request from the repository whatever the case of its stored name' do
    fixture = github_issue_fixture('issue_79')
    events = described_class.new(repo_name: 'BendyCode/PRMetrics', issue: fixture.issue, timeline: fixture.timeline).events

    expect(events.pluck(:kind).tally).to include(commit_referenced: 5, pull_request_linked: 4)
  end

  it 'builds an ID for an event without one from its time in UTC, whatever the app\'s zone' do
    linked = events_for('issue_79').find { |event| event[:kind] == :pull_request_linked }

    expect(linked[:external_id]).to eq('pull_request_linked:86:2026-09-17T11:06:49Z')
  end

  it 'gives an event without a GitHub ID the same ID on every read' do
    first_read = events_for('issue_79').pluck(:external_id)
    second_read = events_for('issue_79').pluck(:external_id)

    expect(second_read).to eq(first_read)
  end
end
