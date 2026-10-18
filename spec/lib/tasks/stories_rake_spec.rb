require 'rails_helper'
require 'rake'

RSpec.describe 'story rake tasks' do
  before do
    Rake.application.rake_require 'tasks/stories'
    Rake.application.rake_require 'tasks/trackers'
    Rake::Task.define_task(:environment)
    Rake::Task['sync:stories'].reenable
    Rake::Task['trackers:create_github_issues'].reenable
    Rake::Task['trackers:create_shortcut'].reenable
    Rake::Task['trackers:set_token'].reenable
    Rake::Task['trackers:set_teams'].reenable
  end

  describe 'sync:stories' do
    let!(:first) { create(:tracker) }
    let!(:second) { create(:tracker) }
    let(:first_sync) { instance_double(GithubIssueSync, sync!: nil) }
    let(:second_sync) { instance_double(GithubIssueSync, sync!: nil) }

    before do
      allow(GithubIssueSync).to receive(:new).with(first, full: false).and_return(first_sync)
      allow(GithubIssueSync).to receive(:new).with(second, full: false).and_return(second_sync)
    end

    # The nightly workflow's log is public, and a tracker's repository may not be
    it 'syncs every tracker, naming each by its ID alone' do
      expect { Rake::Task['sync:stories'].invoke }
        .to output(a_string_matching(/Synced stories for tracker #{first.id}.*Synced 2 of 2 trackers/m)
          .and(exclude(first.source_repository.name))).to_stdout

      expect([first_sync, second_sync]).to all(have_received(:sync!))
    end

    it 'syncs the other trackers when one fails, then reports the failure' do
      allow(first_sync).to receive(:sync!).and_raise(Octokit::ServerError)

      expect { Rake::Task['sync:stories'].invoke }
        .to output(/Synced 1 of 2 trackers/).to_stdout.and raise_error(SystemExit)
      expect(second_sync).to have_received(:sync!)
    end

    it 'logs a failure without the message, which can quote the repository\'s URL' do
      allow(Rails.logger).to receive(:error)
      allow(first_sync).to receive(:sync!).and_raise(github_error("repos/#{first.source_repository.name}/issues"))

      expect { Rake::Task['sync:stories'].invoke }.to output.to_stdout.and raise_error(SystemExit)
      expect(Rails.logger).to have_received(:error).with(include("tracker #{first.id}"))
      expect(Rails.logger).not_to have_received(:error).with(include(first.source_repository.name))
    end

    it 'reads every story of every tracker again with FETCH_ALL=true' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('FETCH_ALL').and_return('true')
      allow(GithubIssueSync).to receive(:new).with(first, full: true).and_return(first_sync)
      allow(GithubIssueSync).to receive(:new).with(second, full: true).and_return(second_sync)

      expect { Rake::Task['sync:stories'].invoke }.to output(/Synced 2 of 2 trackers/).to_stdout
      expect(GithubIssueSync).to have_received(:new).with(first, full: true)
      expect(GithubIssueSync).to have_received(:new).with(second, full: true)
    end

    # GithubIssueSync's own spec covers the token check that raises this
    it 'syncs the other trackers when one cannot start, then reports it' do
      allow(GithubIssueSync).to receive(:new).with(first, full: false).and_raise(GithubIssueSync::MissingToken)

      expect { Rake::Task['sync:stories'].invoke }
        .to output(/tracker #{first.id}: GithubIssueSync::MissingToken.*Synced 1 of 2 trackers/m).to_stdout
        .and raise_error(SystemExit)
      expect(second_sync).to have_received(:sync!)
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
      expect(Tracker.sole).to have_attributes(id: existing.id, config: {})
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

    it 'refuses a key prefix that is not capital letters and digits' do
      expect { Rake::Task['trackers:create_github_issues'].invoke('bendycode/prmetrics', 'prm-') }
        .to output(/Key prefix is invalid/).to_stdout.and raise_error(SystemExit)
      expect(Tracker.count).to be(0)
    end

    it 'fails with a clear message when the repository has not been added' do
      expect { Rake::Task['trackers:create_github_issues'].invoke('bendycode/elsewhere') }
        .to output(%r{Repository bendycode/elsewhere not found}).to_stdout.and raise_error(SystemExit)
      expect(Tracker.count).to be(0)
    end
  end

  describe 'trackers:create_shortcut' do
    let!(:first_repository) { create(:repository, name: 'owner/first') }
    let!(:second_repository) { create(:repository, name: 'owner/second') }

    before { allow(TokenPrompt).to receive(:read).with('SHORTCUT_API_TOKEN').and_return('shortcut-secret') }

    it 'creates a Shortcut tracker for the workflow, covering every repository named' do
      expect { Rake::Task['trackers:create_shortcut'].invoke('500', 'owner/first', 'owner/second') }
        .to output(%r{Created Shortcut tracker \d+ covering owner/first and owner/second}).to_stdout

      tracker = first_repository.reload.tracker
      expect(tracker).to have_attributes(kind: 'shortcut', workflow_id: '500', api_token: 'shortcut-secret')
      expect(second_repository.reload.tracker).to eq(tracker)
      expect(TokenPrompt).to have_received(:read).with('SHORTCUT_API_TOKEN')
    end

    it 'covers a repository named twice once' do
      expect { Rake::Task['trackers:create_shortcut'].invoke('500', 'owner/first', 'owner/first') }
        .to output(%r{covering owner/first\. }).to_stdout

      expect(first_repository.reload.tracker).to be_shortcut
    end

    it 'never prints the token' do
      expect { Rake::Task['trackers:create_shortcut'].invoke('500', 'owner/first') }
        .to output(exclude('shortcut-secret')).to_stdout
    end

    it 'refuses without a token' do
      allow(TokenPrompt).to receive(:read).with('SHORTCUT_API_TOKEN').and_return(nil)

      expect { Rake::Task['trackers:create_shortcut'].invoke('500', 'owner/first') }
        .to output(/Api token can't be blank/).to_stdout.and raise_error(SystemExit)
      expect(Tracker.count).to be(0)
      expect(first_repository.reload.tracker).to be_nil
    end

    it 'refuses a workflow that is not a number, before asking for a token' do
      expect { Rake::Task['trackers:create_shortcut'].invoke('owner/first', 'owner/second') }
        .to output(/Workflow is invalid/).to_stdout.and raise_error(SystemExit)
      expect(Tracker.count).to be(0)
      expect(second_repository.reload.tracker).to be_nil
      expect(TokenPrompt).not_to have_received(:read)
    end

    it 'refuses without a repository to cover, before asking for a token' do
      expect { Rake::Task['trackers:create_shortcut'].invoke('500') }
        .to output(/Name at least one repository/).to_stdout.and raise_error(SystemExit)
      expect(Tracker.count).to be(0)
      expect(TokenPrompt).not_to have_received(:read)
    end

    it 'refuses a repository that has not been added, before asking for a token' do
      expect { Rake::Task['trackers:create_shortcut'].invoke('500', 'owner/first', 'owner/elsewhere') }
        .to output(%r{Repository owner/elsewhere not found}).to_stdout.and raise_error(SystemExit)
      expect(Tracker.count).to be(0)
      expect(TokenPrompt).not_to have_received(:read)
    end

    it 'refuses a repository another tracker already covers, before asking for a token' do
      other = create(:tracker)
      second_repository.update!(tracker: other)

      expect { Rake::Task['trackers:create_shortcut'].invoke('500', 'owner/first', 'owner/second') }
        .to output(%r{owner/second is already covered by tracker #{other.id}}).to_stdout.and raise_error(SystemExit)
      expect(first_repository.reload.tracker).to be_nil
      expect(Tracker.count).to be(1)
      expect(TokenPrompt).not_to have_received(:read)
    end

    it 'refuses before asking for a token when the encryption keys are not set' do
      allow(ActiveRecord::Encryption.config).to receive(:primary_key)
        .and_raise(ActiveRecord::Encryption::Errors::Configuration, 'Missing Active Record encryption credential')

      expect { Rake::Task['trackers:create_shortcut'].invoke('500', 'owner/first') }
        .to output(/encryption keys are not set/).to_stdout.and raise_error(SystemExit)
      expect(TokenPrompt).not_to have_received(:read)
      expect(Tracker.count).to be(0)
    end

    it 'refuses a repository another tracker covered while it waited for the token' do
      other = create(:tracker)
      allow(TokenPrompt).to receive(:read).with('SHORTCUT_API_TOKEN') do
        second_repository.update!(tracker: other)
        'shortcut-secret'
      end

      expect { Rake::Task['trackers:create_shortcut'].invoke('500', 'owner/first', 'owner/second') }
        .to output(%r{owner/second is already covered by tracker #{other.id}}).to_stdout.and raise_error(SystemExit)
      expect(first_repository.reload.tracker).to be_nil
      expect(Tracker.shortcut.count).to be(0)
    end
  end

  describe 'trackers:set_token' do
    let!(:tracker) { create(:tracker, :shortcut, api_token: 'old-secret') }

    before { allow(TokenPrompt).to receive(:read).with('SHORTCUT_API_TOKEN').and_return('new-secret') }

    it 'replaces the tracker\'s token without printing either one' do
      expect { Rake::Task['trackers:set_token'].invoke(tracker.id.to_s) }
        .to output(a_string_matching(/Replaced the token for tracker #{tracker.id}/)
          .and(exclude('new-secret')).and(exclude('old-secret'))).to_stdout

      expect(tracker.reload.api_token).to eq('new-secret')
    end

    it 'replaces a token stored under encryption keys the app no longer has' do
      old_keys = ActiveRecord::Encryption::DerivedSecretKeyProvider.new('a-primary-key-since-replaced')
      unreadable = ActiveRecord::Encryption.with_encryption_context(key_provider: old_keys) do
        create(:tracker, :shortcut, workflow_id: '600', api_token: 'old-secret')
      end

      expect { Rake::Task['trackers:set_token'].invoke(unreadable.id.to_s) }
        .to output(/Replaced the token for tracker #{unreadable.id}/).to_stdout
      expect(Tracker.find(unreadable.id).api_token).to eq('new-secret')
    end

    it 'refuses before asking for a token when the encryption keys are not set' do
      allow(ActiveRecord::Encryption.config).to receive(:primary_key)
        .and_raise(ActiveRecord::Encryption::Errors::Configuration, 'Missing Active Record encryption credential')

      expect { Rake::Task['trackers:set_token'].invoke(tracker.id.to_s) }
        .to output(/encryption keys are not set/).to_stdout.and raise_error(SystemExit)
      expect(TokenPrompt).not_to have_received(:read)
    end

    it 'leaves the token alone when none is entered' do
      allow(TokenPrompt).to receive(:read).with('SHORTCUT_API_TOKEN').and_return(nil)

      expect { Rake::Task['trackers:set_token'].invoke(tracker.id.to_s) }
        .to output(/Api token can't be blank/).to_stdout.and raise_error(SystemExit)
      expect(tracker.reload.api_token).to eq('old-secret')
    end

    it 'fails with a clear message for a tracker that does not exist, before asking for a token' do
      expect { Rake::Task['trackers:set_token'].invoke('0') }
        .to output(/Tracker 0 not found/).to_stdout.and raise_error(SystemExit)
      expect(TokenPrompt).not_to have_received(:read)
    end

    it 'shows how to call it when no tracker is named' do
      expect { Rake::Task['trackers:set_token'].invoke }
        .to output(/Usage: rake trackers:set_token\[tracker_id\]/).to_stdout.and raise_error(SystemExit)
      expect(TokenPrompt).not_to have_received(:read)
    end

    it 'refuses a tracker of a kind that reads with no token of its own, before asking for a token' do
      github = create(:tracker)

      expect { Rake::Task['trackers:set_token'].invoke(github.id.to_s) }
        .to output(/Tracker #{github.id} is a github_issues tracker, which reads with GITHUB_ACCESS_TOKEN/).to_stdout
        .and raise_error(SystemExit)
      expect(TokenPrompt).not_to have_received(:read)
    end
  end

  describe 'trackers:set_teams' do
    let!(:tracker) { create(:tracker, :shortcut, workflow_id: '100') }
    let(:shortcut) { instance_double(ShortcutService, groups: shortcut_fixture('groups')) }

    before { allow(ShortcutService).to receive(:new).with(tracker.api_token).and_return(shortcut) }

    it 'limits a Shortcut tracker to the teams named, once each' do
      expect { Rake::Task['trackers:set_teams'].invoke(tracker.id.to_s, 'team-1', 'team-2', 'team-1') }
        .to output(/Tracker #{tracker.id} now reads the stories of 2 teams/).to_stdout

      expect(tracker.reload.team_ids).to eq(%w[team-1 team-2])
    end

    it 'reads every team again when none is named' do
      tracker.update!(team_ids: ['team-1'])

      expect { Rake::Task['trackers:set_teams'].invoke(tracker.id.to_s) }
        .to output(/Tracker #{tracker.id} now reads the stories of every team/).to_stdout

      expect(tracker.reload.team_ids).to be_nil
    end

    # A mistyped ID would leave the tracker reading no story at all
    it 'refuses a team that does not use the tracker\'s workflow' do
      expect { Rake::Task['trackers:set_teams'].invoke(tracker.id.to_s, 'team-1', 'team-3', 'team-x') }
        .to output(/team-3 and team-x are not teams on workflow 100/).to_stdout.and raise_error(SystemExit)

      expect(tracker.reload.team_ids).to be_nil
    end

    it 'ignores a blank team, as a trailing comma gives' do
      expect { Rake::Task['trackers:set_teams'].invoke(tracker.id.to_s, 'team-1', '') }.to output.to_stdout

      expect(tracker.reload.team_ids).to eq(['team-1'])
    end

    it 'shows how to call it when no tracker is named' do
      expect { Rake::Task['trackers:set_teams'].invoke }
        .to output(/Usage: rake trackers:set_teams\[tracker_id,team_id,\.\.\.\]/).to_stdout.and raise_error(SystemExit)
    end

    it 'fails with a clear message for a tracker that does not exist' do
      expect { Rake::Task['trackers:set_teams'].invoke('0', 'team-1') }
        .to output(/Tracker 0 not found/).to_stdout.and raise_error(SystemExit)
    end

    it 'refuses a tracker that is not a Shortcut tracker' do
      github = create(:tracker)

      expect { Rake::Task['trackers:set_teams'].invoke(github.id.to_s, 'team-1') }
        .to output(/Tracker #{github.id} is a github_issues tracker, which has no teams/).to_stdout
        .and raise_error(SystemExit)
    end
  end
end
