require 'rails_helper'

RSpec.describe Contributor do
  describe 'a contributor who merged pull requests' do
    let(:merger) { create(:contributor) }
    let!(:merged) { create(:pull_request, merged_by: merger, gh_merged_at: 2.days.ago) }

    it 'can be destroyed, leaving the pull request with no merger' do
      expect { merger.destroy }.to change { merged.reload.merged_by }.from(merger).to(nil)
    end

    it 'counts as taking part, so it is not orphaned' do
      expect(described_class.orphaned).to be_empty
    end
  end

  describe '.find_or_create_from_github' do
    # GitHub reports the account type; a GitHub App's login usually ends in
    # [bot], but an account like Copilot does not, which is why the type rules
    def github_user(id, login, type)
      double(id: id, login: login, name: nil, avatar_url: nil, email: nil, type: type)
    end

    it 'flags a contributor GitHub reports as a Bot' do
      contributor = described_class.find_or_create_from_github(github_user(9_100_001, 'copilot-style-name', 'Bot'))

      expect(contributor).to be_bot
    end

    it 'leaves a person unflagged' do
      expect(described_class.find_or_create_from_github(github_user(9_100_002, 'a-person', 'User'))).not_to be_bot
    end

    it 'flags a contributor stored before GitHub reported it as a Bot' do
      stored = create(:contributor, github_id: '9100003', username: 'stored-earlier', bot: false)

      described_class.find_or_create_from_github(github_user(9_100_003, 'stored-earlier', 'Bot'))

      expect(stored.reload).to be_bot
    end

    it 'leaves a flagged contributor flagged when GitHub says nothing about its type' do
      stored = create(:contributor, github_id: '9100004', username: 'known-bot', bot: true)
      typeless = double(id: 9_100_004, login: 'known-bot', name: nil, avatar_url: nil, email: nil)

      described_class.find_or_create_from_github(typeless)

      expect(stored.reload).to be_bot
    end
  end

  describe '.orphaned' do
    it 'finds a contributor with no pull requests, reviews or participation' do
      unused = create(:contributor)

      expect(described_class.orphaned).to contain_exactly(unused)
    end
  end

  describe 'validations' do
    it 'is valid with valid attributes' do
      contributor = Contributor.new(
        username: 'testuser',
        name: 'Test User',
        email: 'test@example.com',
        github_id: '12345'
      )
      expect(contributor).to be_valid
    end

    it 'is not valid without a username' do
      contributor = Contributor.new(
        name: 'Test User',
        email: 'test@example.com',
        github_id: '12345'
      )
      expect(contributor).not_to be_valid
    end

    it 'is not valid without a github_id' do
      contributor = Contributor.new(
        username: 'testuser',
        name: 'Test User',
        email: 'test@example.com'
      )
      expect(contributor).not_to be_valid
    end

    it 'validates uniqueness of github_id' do
      create(:contributor, github_id: '12345')
      duplicate = build(:contributor, github_id: '12345')
      expect(duplicate).not_to be_valid
    end

    it 'validates uniqueness of username' do
      create(:contributor, username: 'testuser')
      duplicate = build(:contributor, username: 'testuser', github_id: 'different_id')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:username]).to include('has already been taken')
    end
  end

  describe 'associations' do
    it 'has many authored pull requests' do
      association = described_class.reflect_on_association(:authored_pull_requests)
      expect(association.macro).to eq :has_many
      expect(association.options[:class_name]).to eq 'PullRequest'
      expect(association.options[:foreign_key]).to eq 'author_id'
    end

    it 'has many pull request users' do
      association = described_class.reflect_on_association(:pull_request_users)
      expect(association.macro).to eq :has_many
      expect(association.options[:foreign_key]).to eq 'user_id'
    end

    it 'has many participated pull requests through pull request users' do
      association = described_class.reflect_on_association(:participated_pull_requests)
      expect(association.macro).to eq :has_many
      expect(association.options[:through]).to eq :pull_request_users
      expect(association.options[:source]).to eq :pull_request
    end

    it 'has many reviews' do
      association = described_class.reflect_on_association(:reviews)
      expect(association.macro).to eq :has_many
      expect(association.options[:foreign_key]).to eq 'author_id'
    end
  end

  describe 'class methods' do
    describe '.find_or_create_from_github' do
      let(:github_user) do
        double(
          id: 123,
          login: 'octocat',
          name: 'The Octocat',
          avatar_url: 'https://github.com/avatar.png',
          email: 'octocat@github.com'
        )
      end

      it 'creates a new contributor from github data' do
        contributor = Contributor.find_or_create_from_github(github_user)

        expect(contributor.github_id).to eq '123'
        expect(contributor.username).to eq 'octocat'
        expect(contributor.name).to eq 'The Octocat'
        expect(contributor.avatar_url).to eq 'https://github.com/avatar.png'
        expect(contributor.email).to eq 'octocat@github.com'
      end

      it 'finds existing contributor by github_id' do
        existing = create(:contributor, github_id: '123')
        contributor = Contributor.find_or_create_from_github(github_user)

        expect(contributor.id).to eq existing.id
      end
    end

    describe '.find_or_create_from_username' do
      it 'creates a new contributor with placeholder github_id' do
        contributor = Contributor.find_or_create_from_username('newuser', {
                                                                 name: 'New User',
                                                                 email: 'new@example.com'
                                                               })

        expect(contributor.username).to eq 'newuser'
        expect(contributor.github_id).to start_with('placeholder_')
        expect(contributor.name).to eq 'New User'
        expect(contributor.email).to eq 'new@example.com'
      end

      it 'finds existing contributor by username' do
        existing = create(:contributor, username: 'existinguser')
        contributor = Contributor.find_or_create_from_username('existinguser')

        expect(contributor.id).to eq existing.id
      end
    end
  end

  describe 'instance methods' do
    let(:contributor) { create(:contributor, name: 'John Doe', username: 'johndoe') }

    describe '#display_name' do
      it 'returns name when present' do
        expect(contributor.display_name).to eq 'John Doe'
      end

      it 'returns username when name is blank' do
        contributor.name = ''
        expect(contributor.display_name).to eq 'johndoe'
      end
    end

    describe '#has_github_data?' do
      it 'returns true for real github_id' do
        contributor.github_id = '12345'
        expect(contributor.has_github_data?).to be true
      end

      it 'returns false for placeholder github_id' do
        contributor.github_id = 'placeholder_abc123'
        expect(contributor.has_github_data?).to be false
      end

      it 'returns false for user_ prefix github_id' do
        contributor.github_id = 'user_123'
        expect(contributor.has_github_data?).to be false
      end
    end
  end
end
