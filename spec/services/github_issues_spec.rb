require 'rails_helper'

RSpec.describe GithubIssues do
  let(:service) { GithubService.new('mock_access_token') }
  let(:octokit_client) { instance_double(Octokit::Client) }

  before do
    allow(Octokit::Client).to receive(:new).and_return(octokit_client)
    allow(octokit_client).to receive(:auto_paginate=)
  end

  describe '#issues' do
    it 'reads every page, leaving out the pull requests GitHub lists among the issues' do
      issue = { number: 1 }
      pull_request = { number: 2, pull_request: { url: 'https://api.github.com/repos/o/r/pulls/2' } }
      pages = [Array.new(100) { github_resource(issue) }, [github_resource(pull_request), github_resource(issue)]]
      allow(octokit_client).to receive(:list_issues) { |_repo, options| pages[options[:page] - 1] || [] }

      expect(service.issues('o/r').size).to be(101)
    end

    it 'asks for closed issues as well as open ones' do
      allow(octokit_client).to receive(:list_issues).and_return([])

      service.issues('o/r')

      expect(octokit_client).to have_received(:list_issues).with('o/r', hash_including(state: 'all'))
    end
  end

  describe '#issue_timeline' do
    it 'reads every page' do
      pages = [Array.new(100) { github_resource(event: 'referenced') }, [github_resource(event: 'closed')]]
      allow(octokit_client).to receive(:issue_timeline) { |_repo, _number, options| pages[options[:page] - 1] || [] }

      expect(service.issue_timeline('o/r', 79).size).to be(101)
    end
  end
end
