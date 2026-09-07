require 'rails_helper'

RSpec.describe 'Pagination params' do
  let(:user) { create(:user) }
  let(:repository) { create(:repository) }
  let(:pull_request) { create(:pull_request, repository: repository) }
  let(:contributor) { create(:contributor) }

  before { sign_in user }

  hostile_pages = {
    'an array' => 'page[]=1',
    'a hash' => 'page[a]=1',
    'a number past bigint' => 'page=999999999999999999999999'
  }

  paginated_routes = {
    'repositories#show' => -> { repository_path(repository) },
    'pull_requests#index' => -> { repository_pull_requests_path(repository) },
    'pull_requests#show' => -> { pull_request_path(pull_request) },
    'contributors#index' => -> { contributors_path },
    'contributors#show' => -> { contributor_path(contributor) },
    'pull_request_users#index' => -> { pull_request_pull_request_users_path(pull_request) },
    'reviews#index' => -> { pull_request_reviews_path(pull_request) }
  }

  paginated_routes.each do |action, path_builder|
    describe action do
      let(:path) { instance_exec(&path_builder) }

      hostile_pages.each do |shape, query|
        it "renders when page is #{shape}" do
          get "#{path}?#{query}"

          expect(response).to have_http_status(:ok)
        end
      end
    end
  end

  describe 'contributors#index page selection' do
    before do
      (1..11).each { |n| create(:contributor, username: format('user_%02d', n)) }
    end

    hostile_pages.each do |shape, query|
      it "shows the first page when page is #{shape}" do
        get "#{contributors_path}?#{query}"

        expect(response.body).to include('user_01')
        expect(response.body).not_to include('user_11')
      end
    end

    it 'shows the second page for page=2' do
      get contributors_path, params: { page: 2 }

      expect(response.body).to include('user_11')
      expect(response.body).not_to include('user_01')
    end
  end

  describe 'weeks#show links' do
    let(:week) { create(:week, repository: repository) }

    it 'drops an invalid page value from the Back to Repository link' do
      get "#{repository_week_path(repository, week)}?page[]=1"

      expect(response.body).to include(%(href="#{repository_path(repository)}"))
      expect(response.body).not_to include('page%5B%5D')
    end

    it 'carries a valid page value into the Back to Repository link' do
      get repository_week_path(repository, week), params: { page: 2 }

      expect(response.body).to include(%(href="#{repository_path(repository, page: 2)}"))
    end
  end
end
