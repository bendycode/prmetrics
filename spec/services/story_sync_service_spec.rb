require 'rails_helper'

RSpec.describe StorySyncService do
  let(:repository) { create(:repository, name: 'bendycode/prmetrics') }
  let(:tracker) { create(:tracker, source_repository: repository, key_prefix: 'PRM') }
  let(:github) { instance_double(GithubService) }
  let(:fixture) { github_issue_fixture('issue_79') }
  let(:sync) { described_class.new(tracker, github: github) }

  before do
    allow(github).to receive(:issues).with('bendycode/prmetrics').and_return([fixture.issue])
    allow(github).to receive(:issue_timeline).with('bendycode/prmetrics', 79).and_return(fixture.timeline)
  end

  it 'stores each issue as a story under the project\'s key' do
    sync.sync!

    expect(tracker.stories.sole).to have_attributes(
      external_id: '79', key: 'PRM-79', title: 'Limit users to granted repositories',
      url: 'https://github.com/bendycode/prmetrics/issues/79', state: 'closed', state_reason: 'completed'
    )
  end

  it 'measures each story from its timeline' do
    sync.sync!

    expect(tracker.stories.sole).to have_attributes(
      committed_at: Time.zone.parse('2026-09-17T09:57:04Z'), committed_source: 'opened',
      started_at: Time.zone.parse('2026-09-17T10:42:46Z'), started_source: 'assigned',
      done_at: Time.zone.parse('2026-09-20T17:10:13Z')
    )
  end

  it 'stores each event once when a later sync reads the timeline again' do
    sync.sync!
    updated = github_resource(fixture.issue.to_h.merge(updated_at: fixture.issue.updated_at + 1.day))
    allow(github).to receive(:issues).with('bendycode/prmetrics').and_return([updated])

    expect { described_class.new(tracker, github: github).sync! }.not_to(change(StoryEvent, :count))
    expect(github).to have_received(:issue_timeline).twice
  end

  context 'when an issue is stored at the update GitHub lists' do
    let!(:story) do
      create(:story, tracker: tracker, external_id: '79', gh_updated_at: fixture.issue.updated_at,
                     listed_at: fixture.issue.updated_at + 1.hour)
    end

    before { create(:story_event, story: story, kind: :opened, occurred_at: Time.zone.parse('2026-09-17T09:57:04Z')) }

    it 'reads nothing more from its timeline' do
      sync.sync!

      expect(github).not_to have_received(:issue_timeline)
    end

    it 'still measures it again' do
      sync.sync!

      expect(story.reload.committed_at).to eq(Time.zone.parse('2026-09-17T09:57:04Z'))
    end
  end

  # A commit or pull request that mentions an issue adds to its timeline
  # without moving its updated_at; closing the issue does move it.
  it 'reads an open issue\'s timeline on every sync' do
    open_issue = github_resource(fixture.issue.to_h.merge(state: 'open', state_reason: nil, closed_at: nil))
    allow(github).to receive(:issues).with('bendycode/prmetrics').and_return([open_issue])
    create(:story, tracker: tracker, external_id: '79', gh_updated_at: open_issue.updated_at,
                   listed_at: open_issue.updated_at + 1.hour)

    sync.sync!

    expect(github).to have_received(:issue_timeline).with('bendycode/prmetrics', 79)
  end

  it 'reads an issue again once it has changed since it was stored' do
    create(:story, tracker: tracker, external_id: '79', gh_updated_at: fixture.issue.updated_at - 1.day,
                   listed_at: fixture.issue.updated_at - 1.hour)

    sync.sync!

    expect(github).to have_received(:issue_timeline).with('bendycode/prmetrics', 79)
  end

  it 'reads an issue again when it was stored before GitHub listed its update' do
    create(:story, tracker: tracker, external_id: '79', gh_updated_at: fixture.issue.updated_at,
                   listed_at: fixture.issue.updated_at)

    sync.sync!

    expect(github).to have_received(:issue_timeline)
  end

  context 'when an issue cannot be read' do
    let(:other) { github_issue_fixture('issue_not_planned') }

    before do
      allow(github).to receive(:issues).with('bendycode/prmetrics').and_return([fixture.issue, other.issue])
      allow(github).to receive(:issue_timeline).with('bendycode/prmetrics', 79).and_raise(Octokit::ServerError)
      allow(github).to receive(:issue_timeline).with('bendycode/prmetrics', 9002).and_return(other.timeline)
    end

    it 'stores nothing for that issue, and names it once the others are synced' do
      expect { sync.sync! }.to raise_error(StorySyncService::IssuesFailed, /#79/)
      expect(tracker.stories.pluck(:external_id)).to eq(['9002'])
    end

    it 'still measures the issues it could read' do
      expect { sync.sync! }.to raise_error(StorySyncService::IssuesFailed)
      expect(tracker.stories.sole).to have_attributes(committed_source: 'opened', started_source: 'assigned', done_at: nil)
    end
  end

  describe 'an issue GitHub no longer lists' do
    it 'is marked gone, as a transferred or deleted issue is' do
      transferred = create(:story, tracker: tracker, external_id: '12')
      allow(github).to receive(:issue_gone?).with('bendycode/prmetrics', 12).and_return(true)

      sync.sync!

      expect([transferred.reload.gone, tracker.stories.find_by!(external_id: '79').gone]).to eq([true, false])
    end

    # A deletion during a long listing shifts later issues back a page.
    it 'is kept when GitHub still serves it though the listing missed it' do
      missed = create(:story, tracker: tracker, external_id: '12')
      allow(github).to receive(:issue_gone?).with('bendycode/prmetrics', 12).and_return(false)

      sync.sync!

      expect(missed.reload.gone).to be(false)
    end

    it 'is no longer gone once GitHub lists it again' do
      returned = create(:story, tracker: tracker, external_id: '79', gone: true,
                                gh_updated_at: fixture.issue.updated_at, listed_at: fixture.issue.updated_at + 1.hour)

      sync.sync!

      expect(returned.reload.gone).to be(false)
    end
  end
end
