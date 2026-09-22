require 'rails_helper'

RSpec.describe PullRequestRefsBackfill do
  let(:repository) { create(:repository, name: 'owner/app') }
  let(:github_service) { instance_double(GithubService, default_branch: 'main') }
  let(:output) { StringIO.new }
  let(:backfill) { described_class.new(github_service, output: output) }

  # The shape Octokit returns from GitHub's pull request list
  def github_pr(number, base:, head:)
    Sawyer::Resource.new(Sawyer::Agent.new('https://api.github.com'),
                         number: number, base: { ref: base }, head: { ref: head })
  end

  before do
    allow(github_service).to receive(:each_pull_request).with('owner/app')
                                                        .and_yield(github_pr(1, base: 'production', head: 'main'))
                                                        .and_yield(github_pr(2, base: 'main', head: 'feature/x'))
                                                        .and_yield(github_pr(3, base: 'main', head: 'feature/y'))
  end

  it "fills each stored pull request's branch names and the repository's default branch" do
    deploy = create(:pull_request, repository: repository, number: 1)
    feature = create(:pull_request, repository: repository, number: 2)

    backfill.run(repository)

    expect([repository.reload.default_branch, deploy.reload.slice(:base_ref, :head_ref),
            feature.reload.slice(:base_ref, :head_ref)])
      .to eq(['main', { 'base_ref' => 'production', 'head_ref' => 'main' },
              { 'base_ref' => 'main', 'head_ref' => 'feature/x' }])
  end

  it 'flags the promotions it uncovers' do
    deploy = create(:pull_request, repository: repository, number: 1)

    backfill.run(repository)

    expect(deploy.reload).to be_promotion
  end

  it 'skips pull requests whose branch names are already filled, so a rerun writes nothing new' do
    filled = create(:pull_request, repository: repository, number: 2, base_ref: 'main', head_ref: 'feature/x')

    expect { backfill.run(repository) }.not_to(change { filled.reload.updated_at })
  end

  it 'ignores pull requests GitHub lists that are not stored yet' do
    expect { backfill.run(repository) }.not_to change(PullRequest, :count)
  end

  it 'reports what it filled' do
    create(:pull_request, repository: repository, number: 1)

    backfill.run(repository)

    expect(output.string).to include('owner/app: filled 1 pull request, flagged 1 promotion')
  end
end
