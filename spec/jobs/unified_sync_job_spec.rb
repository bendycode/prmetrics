require 'rails_helper'

RSpec.describe UnifiedSyncJob do
  let(:repo_name) { 'rails/rails' }

  describe '#perform' do
    let(:repository) { create(:repository, name: repo_name) }
    let(:service) { instance_double(UnifiedSyncService, repository: repository) }

    before do
      allow(UnifiedSyncService).to receive(:new).and_return(service)
      allow(service).to receive(:sync!)
    end

    it 'creates UnifiedSyncService with correct parameters' do
      expect(UnifiedSyncService).to receive(:new).with(
        repo_name,
        fetch_all: false,
        progress_callback: anything
      ).and_return(service)

      described_class.perform_now(repository)
    end

    it 'calls sync! on the service' do
      expect(service).to receive(:sync!)

      described_class.perform_now(repository)
    end

    context 'with fetch_all option' do
      it 'passes fetch_all to the service' do
        expect(UnifiedSyncService).to receive(:new).with(
          repo_name,
          fetch_all: true,
          progress_callback: anything
        ).and_return(service)

        described_class.perform_now(repository, fetch_all: true)
      end
    end

    it 'queues a statistics rebuild once the sync finishes' do
      expect do
        described_class.perform_now(repository)
      end.to have_enqueued_job(UpdateRepositoryStatsJob).with(repository.id)
    end

    it 'leaves the statistics alone when the sync fails' do
      allow(service).to receive(:sync!).and_raise(StandardError, 'GitHub unavailable')

      expect do
        expect { described_class.perform_now(repository) }.to raise_error(StandardError, 'GitHub unavailable')
      end.not_to have_enqueued_job(UpdateRepositoryStatsJob)
    end

    it 'gives up rather than retrying a sync that failed on a record that will not save' do
      allow(service).to receive(:sync!).and_raise(ActiveRecord::RecordInvalid.new(repository))

      expect { described_class.perform_now(repository) }.not_to raise_error
    end

    it 'retries a sync that lost a uniqueness race with an overlapping sync' do
      taken = build(:pull_request)
      taken.errors.add(:number, :taken)
      allow(service).to receive(:sync!).and_raise(ActiveRecord::RecordInvalid.new(taken))

      expect { described_class.perform_now(repository) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'logs progress messages' do
      # The job logs directly with logger.info
      job = described_class.new(repository)
      allow(job.logger).to receive(:info)

      job.perform(repository)

      expect(job.logger).to have_received(:info).with(/Starting unified sync/)
      expect(job.logger).to have_received(:info).with(/Unified sync completed/)
    end

    it 'provides progress callback that logs with UnifiedSync prefix' do
      callback_captured = nil

      allow(UnifiedSyncService).to receive(:new) do |*args|
        options = args.last
        callback_captured = options[:progress_callback]
        service
      end

      job = described_class.new(repository)
      job.perform(repository)

      # Test that the callback logs with the expected prefix
      expect(job.logger).to receive(:info).with('[UnifiedSync] Test progress message')
      callback_captured.call('Test progress message') if callback_captured
    end
  end

  describe 'a repository deleted before its sync runs' do
    include ActiveJob::TestHelper

    it 'drops the sync rather than recreating the repository' do
      repository = create(:repository, name: repo_name)
      described_class.perform_later(repository)
      repository.destroy

      expect { perform_enqueued_jobs }.not_to change(Repository, :count)
    end

    it 'keeps the sync, to retry, when the database cannot be reached to load the repository' do
      repository = create(:repository, name: repo_name)
      described_class.perform_later(repository)
      allow(GlobalID::Locator).to receive(:locate).and_raise(ActiveRecord::ConnectionNotEstablished)

      expect { perform_enqueued_jobs }.to raise_error(ActiveJob::DeserializationError)
    end
  end

  describe 'job configuration' do
    it 'uses the default queue' do
      expect(described_class.new.queue_name).to eq('default')
    end
  end
end
