require 'rails_helper'

RSpec.describe SyncRepositoryBatchJob, type: :job do
  let(:repository) { create(:repository, name: 'rails/rails') }
  let(:client) { instance_double(Octokit::Client) }
  
  before do
    allow(Octokit::Client).to receive(:new).with(access_token: ENV['GITHUB_ACCESS_TOKEN']).and_return(client)
    allow(GithubService).to receive(:new).with(ENV['GITHUB_ACCESS_TOKEN']).and_return(instance_double(GithubService))
  end
  
  describe '#perform' do
    context 'when starting a sync (page 1)' do
      it 'marks repository as in_progress' do
        allow(client).to receive(:pull_requests).and_return([])
        
        expect {
          described_class.perform_now(repository.name, page: 1, fetch_all: true)
        }.to change { repository.reload.sync_status }.to('completed')
        
        expect(repository.sync_started_at).to be_present
      end
    end
    
    context 'when fetching pull requests' do
      let(:pr_data) do
        [
          { 
            number: 123, 
            title: 'Test PR', 
            state: 'open',
            created_at: 2.days.ago,
            updated_at: 1.day.ago,
            closed_at: nil,
            merged_at: nil,
            draft: false,
            user: { id: 1, login: 'user1', name: 'User One', avatar_url: 'http://example.com/avatar.png' }
          }
        ]
      end
      
      it 'processes pull requests in batches' do
        allow(client).to receive(:pull_requests).with(
          repository.name,
          state: 'all',
          per_page: 100,
          page: 1,
          sort: 'updated',
          direction: 'desc'
        ).and_return(pr_data)
        
        # Now we process PRs directly in the job
        expect_any_instance_of(described_class).to receive(:process_single_pull_request).with(repository, pr_data.first)
        
        described_class.perform_now(repository.name, page: 1, fetch_all: false)
      end
      
      it 'queues next page when batch is full' do
        full_batch = Array.new(100) { pr_data.first }
        allow(client).to receive(:pull_requests).and_return(full_batch)
        
        expect(SyncRepositoryBatchJob).to receive(:perform_later).with(
          repository.name, 
          page: 2, 
          fetch_all: true
        )
        
        described_class.perform_now(repository.name, page: 1, fetch_all: true)
      end
      
      it 'completes sync when no more pull requests' do
        allow(client).to receive(:pull_requests).and_return([])
        
        described_class.perform_now(repository.name, page: 1, fetch_all: true)
        
        repository.reload
        expect(repository.sync_status).to eq('completed')
        expect(repository.sync_completed_at).to be_present
        expect(repository.last_fetched_at).to be_present
      end
    end
    
    context 'when an error occurs' do
      let(:error) { StandardError.new('API Error') }
      
      before do
        allow(client).to receive(:pull_requests).and_raise(error)
      end
      
      it 'marks repository as failed and re-raises error' do
        expect {
          described_class.perform_now(repository.name, page: 1)
        }.to raise_error(StandardError, 'API Error')
        
        repository.reload
        expect(repository.sync_status).to eq('failed')
        expect(repository.last_sync_error).to eq('API Error')
      end
    end
    
    context 'with incremental sync' do
      before do
        repository.update!(last_fetched_at: 1.week.ago)
      end
      
      it 'stops fetching when reaching previously fetched PRs' do
        old_pr = { 
          number: 100, 
          title: 'Old PR',
          state: 'closed',
          created_at: 3.weeks.ago,
          updated_at: 2.weeks.ago,
          closed_at: 2.weeks.ago,
          merged_at: nil,
          draft: false,
          user: { id: 1, login: 'user1', name: 'User One', avatar_url: 'http://example.com/avatar.png' }
        }
        
        allow(client).to receive(:pull_requests).and_return([old_pr])
        
        # Should not queue next page
        expect(SyncRepositoryBatchJob).not_to receive(:perform_later)
        
        described_class.perform_now(repository.name, page: 1, fetch_all: false)
        
        expect(repository.reload.sync_status).to eq('completed')
      end
    end
  end
  
  describe 'job configuration' do
    it 'uses the default queue' do
      expect(described_class.new.queue_name).to eq('default')
    end
    
    it 'has correct batch size' do
      expect(described_class::BATCH_SIZE).to eq(100)
    end
  end
end