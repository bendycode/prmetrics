require 'rails_helper'
require 'rake'

RSpec.describe 'story rake tasks' do
  before do
    Rake.application.rake_require 'tasks/stories'
    Rake.application.rake_require 'tasks/trackers'
    Rake::Task.define_task(:environment)
    Rake::Task['sync:stories'].reenable
    Rake::Task['trackers:create_github_issues'].reenable
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('GITHUB_ACCESS_TOKEN').and_return('test_token')
  end

  describe 'sync:stories' do
    let!(:first) { create(:tracker) }
    let!(:second) { create(:tracker) }
    let(:first_sync) { instance_double(StorySyncService, sync!: nil) }
    let(:second_sync) { instance_double(StorySyncService, sync!: nil) }

    before do
      allow(StorySyncService).to receive(:new).with(first).and_return(first_sync)
      allow(StorySyncService).to receive(:new).with(second).and_return(second_sync)
    end

    # The nightly workflow's log is public, and a tracker's repository may not be
    it 'syncs every tracker, naming each by its ID alone' do
      expect { Rake::Task['sync:stories'].invoke }
        .to output(/Synced stories for tracker #{first.id}.*Synced 2 of 2 trackers/m).to_stdout
        .and(output(exclude(first.source_repository.name)).to_stdout)

      expect([first_sync, second_sync]).to all(have_received(:sync!))
    end

    it 'syncs the other trackers when one fails, then reports the failure' do
      allow(first_sync).to receive(:sync!).and_raise(Octokit::ServerError)

      expect { Rake::Task['sync:stories'].invoke }
        .to output(/Synced 1 of 2 trackers/).to_stdout.and raise_error(SystemExit)
      expect(second_sync).to have_received(:sync!)
    end

    it 'stops before syncing anything without a GitHub token' do
      allow(ENV).to receive(:[]).with('GITHUB_ACCESS_TOKEN').and_return(nil)

      expect { Rake::Task['sync:stories'].invoke }
        .to output(/GITHUB_ACCESS_TOKEN/).to_stdout.and raise_error(SystemExit)
      expect(StorySyncService).not_to have_received(:new)
    end
  end

  describe 'trackers:create_github_issues' do
    let!(:repository) { create(:repository, name: 'bendycode/prmetrics') }

    it 'creates a tracker reading the repository\'s issues and covering the repository' do
      expect { Rake::Task['trackers:create_github_issues'].invoke('bendycode/prmetrics', 'PRM') }
        .to output(%r{Created a GitHub issues tracker for bendycode/prmetrics}).to_stdout

      expect(repository.reload.tracker).to have_attributes(
        kind: 'github_issues', source_repository: repository, config: { 'key_prefix' => 'PRM' }
      )
    end

    it 'leaves an existing tracker as it is' do
      existing = create(:tracker, source_repository: repository)

      expect { Rake::Task['trackers:create_github_issues'].invoke('bendycode/prmetrics') }
        .to output(/already has a GitHub issues tracker/).to_stdout
      expect([Tracker.sole, existing.reload.config]).to eq([existing, {}])
    end

    it 'refuses a repository another tracker already covers' do
      other = create(:tracker)
      repository.update!(tracker: other)

      expect { Rake::Task['trackers:create_github_issues'].invoke('bendycode/prmetrics') }
        .to output(/already covered by tracker #{other.id}/).to_stdout.and raise_error(SystemExit)
      expect(repository.reload.tracker).to eq(other)
    end

    it 'keys stories by GitHub number when no prefix is given' do
      expect { Rake::Task['trackers:create_github_issues'].invoke('bendycode/prmetrics') }.to output.to_stdout

      expect(repository.reload.tracker.config).to eq({})
    end

    it 'fails with a clear message when the repository has not been added' do
      expect { Rake::Task['trackers:create_github_issues'].invoke('bendycode/elsewhere') }
        .to output(%r{Repository bendycode/elsewhere not found}).to_stdout.and raise_error(SystemExit)
      expect(Tracker.count).to be(0)
    end
  end
end
