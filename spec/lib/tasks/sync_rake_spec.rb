require 'rails_helper'
require 'rake'

RSpec.describe 'sync:repository rake task' do
  before(:all) do
    Rake.application.rake_require 'tasks/sync'
    Rake::Task.define_task(:environment)
  end

  before(:each) do
    Rake::Task['sync:repository'].reenable
    Rake::Task['sync:status'].reenable
    Rake::Task['sync:list'].reenable
    Rake::Task['sync:all_repositories'].reenable
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('GITHUB_ACCESS_TOKEN').and_return('test_token')
  end

  describe 'sync:repository' do
    let(:service) { instance_double(UnifiedSyncService) }

    context 'with valid arguments' do
      it 'runs unified sync for the specified repository' do
        expect(UnifiedSyncService).to receive(:new).with('rails/rails', fetch_all: false).and_return(service)
        expect(service).to receive(:sync!)

        expect { Rake::Task['sync:repository'].invoke('rails/rails') }.to output(/Starting unified sync/).to_stdout
      end

      it 'respects FETCH_ALL environment variable' do
        allow(ENV).to receive(:[]).with('FETCH_ALL').and_return('true')
        expect(UnifiedSyncService).to receive(:new).with('rails/rails', fetch_all: true).and_return(service)
        expect(service).to receive(:sync!)

        expect { Rake::Task['sync:repository'].invoke('rails/rails') }.to output(/Full sync/).to_stdout
      end
    end

    context 'with missing arguments' do
      it 'shows error when repository name is missing' do
        expect {
          Rake::Task['sync:repository'].invoke
        }.to output(/Error: Repository name is required/).to_stdout.and raise_error(SystemExit)
      end

      it 'handles repository name from ARGV when brackets not used' do
        # Test that both syntaxes work:
        # rake sync:repository[owner/repo] AND rake sync:repository owner/repo
        original_argv = ARGV.dup
        ARGV.replace(['sync:repository', 'PureOxygen/u-app'])

        Rake::Task['sync:repository'].reenable

        expect(UnifiedSyncService).to receive(:new).with('PureOxygen/u-app', fetch_all: false).and_return(service)
        expect(service).to receive(:sync!)

        # Now this should work - repo name taken from ARGV[1]
        expect {
          Rake::Task['sync:repository'].invoke
        }.to output(/Starting unified sync for PureOxygen\/u-app/).to_stdout

        ARGV.replace(original_argv)
      end
    end

    context 'without GitHub token' do
      it 'shows error when GITHUB_ACCESS_TOKEN is not set' do
        allow(ENV).to receive(:[]).with('GITHUB_ACCESS_TOKEN').and_return(nil)

        expect {
          Rake::Task['sync:repository'].invoke('rails/rails')
        }.to output(/GITHUB_ACCESS_TOKEN environment variable is not set/).to_stdout.and raise_error(SystemExit)
      end
    end
  end

  describe 'sync:status' do
    let!(:repository) {
      create(:repository, name: 'rails/rails',
                          sync_status: 'completed',
                          sync_started_at: 1.hour.ago,
                          sync_completed_at: 30.minutes.ago,
                          sync_progress: 100)
    }

    it 'displays repository sync status' do
      output = capture_stdout { Rake::Task['sync:status'].invoke('rails/rails') }

      expect(output).to include('Repository: rails/rails')
      expect(output).to include('Sync Status: completed')
      expect(output).to include('Pull Requests:')
      expect(output).to include('Weeks:')
      expect(output).to include('Reviews:')
    end

    it 'shows error for non-existent repository' do
      expect {
        Rake::Task['sync:status'].invoke('unknown/repo')
      }.to output(/Repository unknown\/repo not found/).to_stdout.and raise_error(SystemExit)
    end
  end

  describe 'sync:list' do
    let!(:repo1) { create(:repository, name: 'rails/rails', sync_status: 'completed') }
    let!(:repo2) { create(:repository, name: 'ruby/ruby', sync_status: 'in_progress', sync_progress: 45) }

    it 'lists all repositories with their sync status' do
      output = capture_stdout { Rake::Task['sync:list'].invoke }

      expect(output).to include('rails/rails')
      expect(output).to include('completed')
      expect(output).to include('ruby/ruby')
      expect(output).to include('in_progress')
      expect(output).to include('45%')
    end

    it 'shows message when no repositories exist' do
      Repository.destroy_all

      expect { Rake::Task['sync:list'].invoke }.to output(/No repositories found/).to_stdout.and raise_error(SystemExit)
    end
  end

  describe 'sync:all_repositories' do
    let(:service1) { instance_double(UnifiedSyncService) }
    let(:service2) { instance_double(UnifiedSyncService) }
    let!(:repo1) { create(:repository, name: 'rails/rails') }
    let!(:repo2) { create(:repository, name: 'ruby/ruby') }

    context 'with valid setup' do
      it 'syncs all repositories successfully' do
        expect(UnifiedSyncService).to receive(:new).with('rails/rails', fetch_all: false).and_return(service1)
        expect(service1).to receive(:sync!)
        expect(UnifiedSyncService).to receive(:new).with('ruby/ruby', fetch_all: false).and_return(service2)
        expect(service2).to receive(:sync!)

        output = capture_stdout { Rake::Task['sync:all_repositories'].invoke }

        expect(output).to include('Starting sync for all repositories')
        expect(output).to include('Repositories to sync: 2')
        expect(output).to include('Syncing rails/rails')
        expect(output).to include('Syncing ruby/ruby')
        expect(output).to include('All repositories synced successfully!')
        expect(output).to include('Successful: 2')
        expect(output).to include('Failed: 0')
      end

      it 'respects FETCH_ALL environment variable' do
        allow(ENV).to receive(:[]).with('FETCH_ALL').and_return('true')
        expect(UnifiedSyncService).to receive(:new).with('rails/rails', fetch_all: true).and_return(service1)
        expect(service1).to receive(:sync!)
        expect(UnifiedSyncService).to receive(:new).with('ruby/ruby', fetch_all: true).and_return(service2)
        expect(service2).to receive(:sync!)

        output = capture_stdout { Rake::Task['sync:all_repositories'].invoke }

        expect(output).to include('Full sync (all PRs)')
      end

      it 'continues processing other repositories when one fails' do
        expect(UnifiedSyncService).to receive(:new).with('rails/rails', fetch_all: false).and_return(service1)
        expect(service1).to receive(:sync!).and_raise(StandardError.new('API error'))
        expect(UnifiedSyncService).to receive(:new).with('ruby/ruby', fetch_all: false).and_return(service2)
        expect(service2).to receive(:sync!)

        expect(Rails.logger).to receive(:error).with(/Sync failed for rails\/rails: API error/)
        expect(Rails.logger).to receive(:error).with(String)

        expect {
          capture_stdout { Rake::Task['sync:all_repositories'].invoke }
        }.to raise_error(SystemExit)
      end
    end

    context 'with no repositories' do
      it 'exits gracefully when no repositories exist' do
        Repository.destroy_all

        expect {
          Rake::Task['sync:all_repositories'].invoke
        }.to output(/No repositories found to sync/).to_stdout.and raise_error(SystemExit)
      end
    end

    context 'without GitHub token' do
      it 'shows error when GITHUB_ACCESS_TOKEN is not set' do
        allow(ENV).to receive(:[]).with('GITHUB_ACCESS_TOKEN').and_return(nil)

        expect {
          Rake::Task['sync:all_repositories'].invoke
        }.to output(/GITHUB_ACCESS_TOKEN environment variable is not set/).to_stdout.and raise_error(SystemExit)
      end
    end
  end

  private

  def capture_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end
end
