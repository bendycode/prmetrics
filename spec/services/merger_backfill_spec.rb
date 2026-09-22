require 'rails_helper'

RSpec.describe MergerBackfill do
  let(:repository) { create(:repository, name: 'owner/app') }
  let(:output) { StringIO.new }
  let(:github_service) { instance_double(GithubService) }
  let(:backfill) { described_class.new(github_service, output: output) }

  # GitHub answers with the merger's login and whether the account is a bot
  def github_merger(number, login, type: 'User')
    { number: number, merged_by: { login: login, id: 9_100_000 + number, type: type } }
  end

  before do
    allow(github_service).to receive(:merged_pull_requests).with('owner/app', after: nil)
                                                           .and_return({ nodes: [github_merger(1, 'the-merger'),
                                                                                 github_merger(2, 'helper[bot]',
                                                                                               type: 'Bot')],
                                                                         has_next_page: false, end_cursor: nil })
  end

  it 'records who merged each stored pull request' do
    merged = create(:pull_request, repository: repository, number: 1, gh_merged_at: 2.days.ago)

    backfill.run(repository)

    expect(merged.reload.merged_by).to have_attributes(username: 'the-merger', bot: false)
  end

  it 'flags a merger GitHub calls a bot' do
    merged = create(:pull_request, repository: repository, number: 2, gh_merged_at: 2.days.ago)

    backfill.run(repository)

    expect(merged.reload.merged_by).to be_bot
  end

  it 'leaves a pull request whose merger it already knows alone' do
    known = create(:contributor, username: 'recorded-earlier')
    merged = create(:pull_request, repository: repository, number: 1, gh_merged_at: 2.days.ago, merged_by: known)

    expect { backfill.run(repository) }.not_to(change { merged.reload.merged_by })
  end

  it 'asks GitHub for nothing when every merger is known' do
    create(:pull_request, repository: repository, number: 1, gh_merged_at: 2.days.ago,
                          merged_by: create(:contributor))

    backfill.run(repository)

    expect(github_service).not_to have_received(:merged_pull_requests)
  end

  it 'reads the next page until it has every merger it needs' do
    create(:pull_request, repository: repository, number: 3, gh_merged_at: 2.days.ago)
    allow(github_service).to receive(:merged_pull_requests).with('owner/app', after: nil)
                                                           .and_return({ nodes: [github_merger(1, 'one')],
                                                                         has_next_page: true, end_cursor: 'cursor-1' })
    allow(github_service).to receive(:merged_pull_requests).with('owner/app', after: 'cursor-1')
                                                           .and_return({ nodes: [github_merger(3, 'three')],
                                                                         has_next_page: false, end_cursor: nil })

    backfill.run(repository)

    expect(repository.pull_requests.find_by(number: 3).merged_by).to have_attributes(username: 'three')
  end

  it 'ignores pull requests GitHub reports that are not stored' do
    create(:pull_request, repository: repository, number: 9, gh_merged_at: 2.days.ago)

    expect { backfill.run(repository) }.not_to change(PullRequest, :count)
  end

  it 'records no merger, and counts none, for an account GitHub gives no id for' do
    merged = create(:pull_request, repository: repository, number: 1, gh_merged_at: 2.days.ago)
    allow(github_service).to receive(:merged_pull_requests)
      .with('owner/app', after: nil)
      .and_return({ nodes: [{ number: 1, merged_by: { login: 'mystery', id: nil, type: 'Mannequin' } }],
                    has_next_page: false, end_cursor: nil })

    backfill.run(repository)

    expect(merged.reload.merged_by).to be_nil
    expect(output.string).to include('recorded 0 mergers')
  end

  it 'reports what it filled' do
    create(:pull_request, repository: repository, number: 1, gh_merged_at: 2.days.ago)

    backfill.run(repository)

    expect(output.string).to include('owner/app: recorded 1 merger')
  end
end
