require 'rails_helper'

RSpec.describe Repository do
  it 'is valid with valid attributes' do
    repository = Repository.new(name: 'test/repo', url: 'https://github.com/test/repo')
    expect(repository).to be_valid
  end

  it 'is not valid without a name' do
    repository = Repository.new(url: 'https://github.com/test/repo')
    expect(repository).not_to be_valid
  end

  it 'auto-generates url when not provided' do
    repository = Repository.new(name: 'test/repo')
    expect(repository).to be_valid
    expect(repository.url).to eq('https://github.com/test/repo')
  end

  it 'validates repository name format' do
    repository = Repository.new(name: 'invalid-name', url: 'https://github.com/test/repo')
    expect(repository).not_to be_valid
    expect(repository.errors[:name]).to include("must be in format 'owner/repository'")
  end

  it 'accepts valid repository name formats' do
    valid_names = ['owner/repo', 'some-org/my-repo', 'user123/test.project']
    valid_names.each do |name|
      repository = Repository.new(name: name, url: "https://github.com/#{name}")
      expect(repository).to be_valid, "Expected #{name} to be valid"
    end
  end

  it 'enforces uniqueness of name' do
    create(:repository, name: 'rails/rails')
    duplicate = Repository.new(name: 'rails/rails', url: 'https://github.com/rails/rails')
    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:name]).to include('has already been taken')
  end

  it 'has many pull requests' do
    association = described_class.reflect_on_association(:pull_requests)
    expect(association.macro).to eq :has_many
  end

  describe '#development_pull_requests' do
    it 'leaves promotions out' do
      repository = create(:repository)
      development = create(:pull_request, repository: repository)
      create(:pull_request, :promotion, repository: repository)

      expect(repository.development_pull_requests).to contain_exactly(development)
    end
  end

  describe '#refresh_promotions!' do
    let(:repository) { create(:repository, default_branch: 'main') }

    def pull_request(head:, base:, promotion: false, merged: true, head_repository: repository.name)
      create(:pull_request, repository: repository, head_ref: head, base_ref: base, promotion: promotion,
                            head_repository: head_repository, gh_merged_at: (Time.current if merged))
    end

    it 'flags pull requests from the default branch into another branch' do
      deploy = pull_request(head: 'main', base: 'production')

      repository.refresh_promotions!

      expect(deploy.reload).to be_promotion
    end

    it 'flags every pull request into a branch the default branch deploys to, whatever its head' do
      pull_request(head: 'main', base: 'production')
      before_rename = pull_request(head: 'master', base: 'production')

      repository.refresh_promotions!

      expect(before_rename.reload).to be_promotion
    end

    it 'leaves development work alone, including stacked and back-merged pull requests' do
      deploy = pull_request(head: 'main', base: 'production')
      development = [
        pull_request(head: 'feature/login', base: 'main'),
        pull_request(head: 'feature/login-part-2', base: 'feature/login'),
        pull_request(head: 'production', base: 'main', merged: false),
        pull_request(head: nil, base: nil)
      ]

      repository.refresh_promotions!

      expect(development.map { |pr| pr.reload.promotion? }).to all(be(false))
      expect(deploy.reload).to be_promotion
    end

    it 'leaves a branch the default branch was merged into to catch it up alone' do
      pull_request(head: 'main', base: 'feature/long-lived')
      stacked = pull_request(head: 'feature/part-2', base: 'feature/long-lived')
      pull_request(head: 'feature/long-lived', base: 'main')

      repository.refresh_promotions!

      expect(stacked.reload).not_to be_promotion
    end

    it "ignores a fork's branch that shares the default branch's name" do
      pull_request(head: 'main', base: 'release-2', head_repository: 'someone-else/app')
      into_release = pull_request(head: 'feature/login', base: 'release-2')

      repository.refresh_promotions!

      expect(into_release.reload).not_to be_promotion
    end

    it "ignores a fork's branch that shares a deploy branch's name" do
      deploy = pull_request(head: 'main', base: 'production')
      pull_request(head: 'production', base: 'main', head_repository: 'someone-else/app')

      repository.refresh_promotions!

      expect(deploy.reload).to be_promotion
    end

    it 'waits for the deploy to merge before treating its branch as a deploy target' do
      pull_request(head: 'main', base: 'production', merged: false)
      later = pull_request(head: 'hotfix', base: 'production')

      repository.refresh_promotions!

      expect(later.reload).not_to be_promotion
    end

    it 'clears the flag once the branch no longer receives pull requests from the default branch' do
      repository.update!(default_branch: 'trunk')
      stale = pull_request(head: 'main', base: 'production', promotion: true)

      repository.refresh_promotions!

      expect(stale.reload).not_to be_promotion
    end

    it 'flags nothing before the default branch is known' do
      repository.update!(default_branch: nil)
      deploy = pull_request(head: 'main', base: 'production')

      repository.refresh_promotions!

      expect(deploy.reload).not_to be_promotion
    end

    it 'returns the pull requests whose flag it cleared as well as those it flagged' do
      repository.update!(default_branch: 'trunk')
      stale = pull_request(head: 'main', base: 'production', promotion: true)

      expect(repository.refresh_promotions!).to contain_exactly(stale)
    end

    it 'changes nothing in a repository with no deploys' do
      pull_request(head: 'feature/login', base: 'main')

      expect(repository.refresh_promotions!).to be_empty
    end

    it 'returns the pull requests whose flag it changed' do
      deploy = pull_request(head: 'main', base: 'production')
      pull_request(head: 'feature/login', base: 'main')

      expect(repository.refresh_promotions!).to contain_exactly(deploy)
    end
  end

  describe '.visible_to' do
    let(:granted_repository) { create(:repository) }
    let!(:other_repository) { create(:repository) }

    it 'returns every repository for an admin' do
      expect(described_class.visible_to(create(:user, :admin))).to include(granted_repository, other_repository)
    end

    it 'returns only the repositories granted to a regular user' do
      user = create(:user)
      grant_access(user, granted_repository)

      expect(described_class.visible_to(user)).to contain_exactly(granted_repository)
    end

    it 'returns nothing for a regular user with no grants' do
      expect(described_class.visible_to(create(:user))).to be_empty
    end
  end
end
