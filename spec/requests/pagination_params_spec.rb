require 'rails_helper'

RSpec.describe 'Pagination params' do
  let(:user) { create(:user) }
  let(:repository) { create(:repository) }
  let(:pull_request) { create(:pull_request, repository: repository) }
  let(:contributor) { create(:contributor) }

  before { sign_in user }

  hostile_pages = {
    'an array' => ['1'],
    'a hash' => { a: '1' },
    'a number past bigint' => '9' * 24
  }

  shared_examples 'a route tolerant of hostile page params' do
    hostile_pages.each do |shape, value|
      it "renders when page is #{shape}" do
        get path, params: { page: value }

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'repositories#show' do
    let(:path) { repository_path(repository) }

    it_behaves_like 'a route tolerant of hostile page params'
  end

  describe 'pull_requests#index' do
    let(:path) { repository_pull_requests_path(repository) }

    it_behaves_like 'a route tolerant of hostile page params'
  end

  describe 'pull_requests#show' do
    let(:path) { pull_request_path(pull_request) }

    it_behaves_like 'a route tolerant of hostile page params'
  end

  describe 'contributors#index' do
    let(:path) { contributors_path }

    it_behaves_like 'a route tolerant of hostile page params'
  end

  describe 'contributors#show' do
    let(:path) { contributor_path(contributor) }

    it_behaves_like 'a route tolerant of hostile page params'
  end

  describe 'pull_request_users#index' do
    let(:path) { pull_request_pull_request_users_path(pull_request) }

    it_behaves_like 'a route tolerant of hostile page params'
  end

  describe 'reviews#index' do
    let(:path) { pull_request_reviews_path(pull_request) }

    it_behaves_like 'a route tolerant of hostile page params'
  end

  describe 'contributors#index page selection' do
    let(:per_page) { 10 }
    let(:first_username) { 'user_01' }
    let(:overflow_username) { format('user_%02d', per_page + 1) }

    before do
      (1..(per_page + 1)).each { |n| create(:contributor, username: format('user_%02d', n)) }
    end

    hostile_pages.each do |shape, value|
      it "shows the first page when page is #{shape}" do
        get contributors_path, params: { page: value }

        expect(response.body).to include(first_username).and exclude(overflow_username)
      end
    end

    it 'shows the second page for page=2' do
      get contributors_path, params: { page: 2 }

      expect(response.body).to include(overflow_username).and exclude(first_username)
    end
  end

  describe 'weeks#show links' do
    let(:monday) { Date.new(2026, 8, 3) }
    let!(:previous_week) { create(:week, repository: repository, begin_date: monday - 7, end_date: monday - 1) }
    let!(:week) { create(:week, repository: repository, begin_date: monday, end_date: monday + 6) }
    let!(:next_week) { create(:week, repository: repository, begin_date: monday + 7, end_date: monday + 13) }

    it 'drops an invalid page value from the Previous, Next, and Back links' do
      get repository_week_path(repository, week), params: { page: ['1'] }

      expect(response.body).to include(
        %(href="#{repository_week_path(repository, previous_week)}"),
        %(href="#{repository_week_path(repository, next_week)}"),
        %(href="#{repository_path(repository)}")
      ).and exclude('page%5B%5D')
    end

    it 'carries a valid page value into the Previous, Next, and Back links' do
      get repository_week_path(repository, week), params: { page: 2 }

      expect(response.body).to include(
        %(href="#{repository_week_path(repository, previous_week, page: 2)}"),
        %(href="#{repository_week_path(repository, next_week, page: 2)}"),
        %(href="#{repository_path(repository, page: 2)}")
      )
    end
  end

  describe 'repositories#show Details links' do
    let(:per_page) { 25 }
    let(:monday) { Date.new(2026, 8, 3) }
    let!(:weeks) do
      (1..(per_page + 1)).map do |n|
        create(:week, repository: repository, week_number: n, begin_date: monday - (n * 7), end_date: monday - (n * 7) + 6)
      end
    end

    it 'drops an invalid page value from the Details links' do
      get repository_path(repository), params: { page: ['1'] }

      expect(response.body).to include(%(href="#{repository_week_path(repository, weeks.first)}"))
        .and exclude('page%5B%5D')
    end

    it 'carries a valid page value into the Details link' do
      get repository_path(repository), params: { page: 2 }

      expect(response.body).to include(%(href="#{repository_week_path(repository, weeks.last, page: 2)}"))
    end
  end
end
