require 'rails_helper'

RSpec.describe TrackerCoverage do
  let(:first) { create(:repository, name: 'owner/first') }
  let(:second) { create(:repository, name: 'owner/second') }
  let(:tracker) { build(:tracker, :shortcut) }

  it 'saves the tracker and covers every repository' do
    described_class.cover!(tracker, [first, second])

    expect([first.reload.tracker, second.reload.tracker]).to all(eq(tracker))
  end

  # As when another run covered a repository while this one waited for its token
  it 'refuses, writing nothing, when a repository was covered after it was read' do
    stale = Repository.find(second.id)
    other = create(:tracker)
    second.update!(tracker: other)

    expect { described_class.cover!(tracker, [first, stale]) }
      .to raise_error(described_class::AlreadyCovered, %r{owner/second is already covered by tracker #{other.id}})
    expect(Tracker.shortcut.count).to be(0)
    expect(first.reload.tracker).to be_nil
    expect(second.reload.tracker).to eq(other)
  end
end
