require 'rails_helper'

RSpec.describe UnifiedSyncJob, type: :job do
  let(:repo_name) { 'rails/rails' }
  
  describe '#perform' do
    let(:service) { instance_double(UnifiedSyncService) }
    
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
      
      described_class.perform_now(repo_name)
    end
    
    it 'calls sync! on the service' do
      expect(service).to receive(:sync!)
      
      described_class.perform_now(repo_name)
    end
    
    context 'with fetch_all option' do
      it 'passes fetch_all to the service' do
        expect(UnifiedSyncService).to receive(:new).with(
          repo_name,
          fetch_all: true,
          progress_callback: anything
        ).and_return(service)
        
        described_class.perform_now(repo_name, fetch_all: true)
      end
    end
    
    it 'logs progress messages' do
      # The job logs directly with logger.info
      job = described_class.new(repo_name)
      expect(job.logger).to receive(:info).with(/Starting unified sync/)
      expect(job.logger).to receive(:info).with(/Unified sync completed/)
      
      job.perform(repo_name)
    end
  end
  
  describe 'job configuration' do
    it 'uses the default queue' do
      expect(described_class.new.queue_name).to eq('default')
    end
  end
end