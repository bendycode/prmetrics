require 'rails_helper'

RSpec.describe SyncRepositoryJob, type: :job do
  let(:repo_name) { 'owner/repo' }
  let(:access_token) { 'test_token' }

  before do
    ENV['GITHUB_ACCESS_TOKEN'] = access_token
  end

  describe '#perform' do
    let(:github_service) { instance_double(GithubService) }
    let(:repository) { create(:repository, name: repo_name) }

    before do
      allow(Repository).to receive(:find_or_create_by).with(name: repo_name).and_return(repository)
      allow(GithubService).to receive(:new).with(access_token).and_return(github_service)
      allow(github_service).to receive(:fetch_and_store_pull_requests)
    end

    it 'updates repository sync status during execution' do
      subject.perform(repo_name)

      expect(repository.reload.sync_status).to eq('completed')
      expect(repository.sync_started_at).to be_present
      expect(repository.sync_completed_at).to be_present
      expect(repository.last_sync_error).to be_nil
    end

    it 'calls GithubService to fetch pull requests' do
      expect(github_service).to receive(:fetch_and_store_pull_requests).with(repo_name, fetch_all: false)

      subject.perform(repo_name)
    end

    it 'handles errors and updates status to failed' do
      error_message = 'API rate limit exceeded'
      allow(github_service).to receive(:fetch_and_store_pull_requests).and_raise(StandardError.new(error_message))

      expect { subject.perform(repo_name) }.to raise_error(StandardError)

      expect(repository.reload.sync_status).to eq('failed')
      expect(repository.last_sync_error).to eq(error_message)
      expect(repository.sync_completed_at).to be_present
    end

    it 'uses provided access token over environment variable' do
      custom_token = 'custom_token'
      expect(GithubService).to receive(:new).with(custom_token).and_return(github_service)

      subject.perform(repo_name, access_token: custom_token)
    end

    it 'returns early if no access token is available' do
      ENV['GITHUB_ACCESS_TOKEN'] = nil

      expect(GithubService).not_to receive(:new)
      expect(Rails.logger).to receive(:error).with(/No GitHub access token/)

      subject.perform(repo_name)
    end

    context 'with fetch_all option' do
      it 'passes fetch_all option to GithubService' do
        expect(github_service).to receive(:fetch_and_store_pull_requests).with(repo_name, fetch_all: true)

        subject.perform(repo_name, fetch_all: true)
      end
    end
  end
end