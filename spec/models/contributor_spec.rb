require 'rails_helper'

RSpec.describe Contributor, type: :model do
  describe 'validations' do
    it "is valid with valid attributes" do
      contributor = Contributor.new(
        username: "testuser", 
        name: "Test User", 
        email: "test@example.com",
        github_id: "12345"
      )
      expect(contributor).to be_valid
    end

    it "is not valid without a username" do
      contributor = Contributor.new(
        name: "Test User", 
        email: "test@example.com",
        github_id: "12345"
      )
      expect(contributor).to_not be_valid
    end
    
    it "is not valid without a github_id" do
      contributor = Contributor.new(
        username: "testuser",
        name: "Test User", 
        email: "test@example.com"
      )
      expect(contributor).to_not be_valid
    end
    
    it "validates uniqueness of github_id" do
      create(:contributor, github_id: "12345")
      duplicate = build(:contributor, github_id: "12345")
      expect(duplicate).to_not be_valid
    end
  end

  describe 'associations' do
    it "has many authored pull requests" do
      association = described_class.reflect_on_association(:authored_pull_requests)
      expect(association.macro).to eq :has_many
      expect(association.options[:class_name]).to eq 'PullRequest'
      expect(association.options[:foreign_key]).to eq 'author_id'
    end
    
    it "has many pull request users" do
      association = described_class.reflect_on_association(:pull_request_users)
      expect(association.macro).to eq :has_many
      expect(association.options[:foreign_key]).to eq 'user_id'
    end

    it "has many participated pull requests through pull request users" do
      association = described_class.reflect_on_association(:participated_pull_requests)
      expect(association.macro).to eq :has_many
      expect(association.options[:through]).to eq :pull_request_users
      expect(association.options[:source]).to eq :pull_request
    end
    
    it "has many reviews" do
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