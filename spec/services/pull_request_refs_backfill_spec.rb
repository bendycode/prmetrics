require 'rails_helper'

RSpec.describe PullRequestRefsBackfill do
  let(:repository) { create(:repository, name: 'owner/app') }
  let(:github_service) { instance_double(GithubService) }
  let(:output) { StringIO.new }
  let(:backfill) { described_class.new(github_service, output: output) }

  # The shape Octokit returns from GitHub's pull request list
  def github_pr(number, base:, head:, head_repository: 'owner/app')
    Sawyer::Resource.new(Sawyer::Agent.new('https://api.github.com'),
                         number: number, base: { ref: base },
                         head: { ref: head, repo: { full_name: head_repository } })
  end

  before do
    allow(github_service).to receive(:default_branch).with('owner/app').and_return('main')
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
    deploy = create(:pull_request, repository: repository, number: 1, gh_merged_at: 2.days.ago)

    backfill.run(repository)

    expect(deploy.reload).to be_promotion
  end

  it 'leaves pull requests whose branch names are already filled as they are' do
    filled = create(:pull_request, repository: repository, number: 2, base_ref: 'develop', head_ref: 'feature/old',
                                   head_repository: 'someone/fork')

    expect { backfill.run(repository) }
      .not_to(change { filled.reload.slice(:base_ref, :head_ref, :head_repository) })
  end

  it 'stops asking GitHub once nothing is left to fill' do
    create(:pull_request, repository: repository, number: 2, base_ref: 'main', head_ref: 'feature/x')

    backfill.run(repository)

    expect(github_service).not_to have_received(:each_pull_request)
  end

  it 'ignores pull requests GitHub lists that are not stored yet' do
    expect { backfill.run(repository) }.not_to change(PullRequest, :count)
  end

  it 'reports what it filled' do
    create(:pull_request, repository: repository, number: 1, gh_merged_at: 2.days.ago)

    backfill.run(repository)

    expect(output.string).to include('owner/app: filled 1 pull request, flagged 1 promotion')
  end
end
