require 'rails_helper'

# Every GET page an application controller serves is visited by a regular
# user granted one repository. A second, ungranted repository carries marker
# text in its name, a pull request title, and each contributor's username; no
# page may render it. Numbers leak without text, so aggregate totals are
# checked in repository_list_visibility_spec.rb instead. A new GET action
# must be added to the page table, or the completeness example fails.
RSpec.describe 'Ungranted repository data never renders' do
  # controller#action => [expected status, path built in the example]
  def self.pages
    list_pages.merge(record_pages)
  end

  def self.list_pages
    {
      'dashboard#index' => [:success, -> { dashboard_path }],
      'dashboard#index filtered to the ungranted repository' =>
        [:success, -> { dashboard_path(repository_id: hidden_repository.id) }],
      'health#show' => [:any, -> { health_path }],
      'accounts#edit' => [:success, -> { edit_account_path }],
      'users#index' => [:redirect, -> { users_path }],
      'users#new' => [:redirect, -> { new_user_path }],
      'repositories#index' => [:success, -> { repositories_path }],
      'repositories#new' => [:redirect, -> { new_repository_path }],
      'contributors#index' => [:success, -> { contributors_path }]
    }
  end

  def self.record_pages
    {
      'repositories#show' => [:success, -> { repository_path(granted_repository) }],
      'pull_requests#index' => [:success, -> { repository_pull_requests_path(granted_repository) }],
      'weeks#show' => [:success, -> { repository_week_path(granted_repository, week) }],
      'pull_requests#show' => [:success, -> { pull_request_path(pull_request) }],
      'reviews#index' => [:success, -> { pull_request_reviews_path(pull_request) }],
      'pull_request_users#index' => [:success, -> { pull_request_pull_request_users_path(pull_request) }],
      'reviews#show' => [:success, -> { review_path(review) }],
      'pull_request_users#show' => [:success, -> { pull_request_user_path(pull_request_user) }],
      'contributors#show' => [:success, -> { contributor_path(shared_contributor) }]
    }
  end

  # The week pull request list is checked per category in its own example.
  def self.covered_actions
    pages.keys.map { |page| page.split.first } + ['weeks#pr_list']
  end

  describe 'the page table' do
    it 'covers every GET action served by an application controller' do
      framework_prefixes = %w[devise/ rails/ turbo/ active_storage/ action_mailbox/]
      actions = Rails.application.routes.routes.filter_map do |route|
        controller = route.defaults[:controller].to_s
        next unless route.verb.include?('GET') && controller.present?
        next if controller.start_with?(*framework_prefixes)

        "#{controller}##{route.defaults[:action]}"
      end

      expect(self.class.covered_actions).to include(*actions.uniq)
    end
  end

  describe 'each page' do
    include_context 'with a regular user granted one repository'

    let(:marker) { 'leakmarker' }
    let(:hidden_repository) { create(:repository, name: "#{marker}/hidden") }
    let(:shared_contributor) { create(:contributor, username: 'shared-contributor') }
    let!(:week) { create(:week, repository: granted_repository, begin_date: week_start, week_number: 1) }
    let!(:pull_request) do
      create(:pull_request, repository: granted_repository, gh_created_at: week_start + 1.day,
                            ready_for_review_at: week_start + 1.day)
    end
    let(:review) { create(:review, pull_request: pull_request) }
    let(:pull_request_user) { create(:pull_request_user, pull_request: pull_request, user: shared_contributor) }

    before do
      # Created up front: the pull request and contributor pages list them
      # even when the page under test is not their own.
      review
      pull_request_user

      create(:week, repository: hidden_repository, begin_date: week_start, week_number: 1)
      hidden_pull_request = create(:pull_request, repository: hidden_repository, title: "#{marker} pull request",
                                                  author: create(:contributor, username: "#{marker}-author"),
                                                  gh_created_at: week_start + 1.day,
                                                  ready_for_review_at: week_start + 1.day)
      create(:review, pull_request: hidden_pull_request, author: create(:contributor, username: "#{marker}-reviewer"))
      create(:pull_request_user, pull_request: hidden_pull_request,
                                 user: create(:contributor, username: "#{marker}-participant"))
      create(:pull_request_user, pull_request: hidden_pull_request, user: shared_contributor)
    end

    def expect_no_ungranted_data(path, status)
      get path

      expect(response).to have_http_status(status) unless status == :any
      expect(response.body.downcase).not_to include(marker), "#{path} rendered ungranted data"
    end

    pages.each do |page, (status, path)|
      it "never renders ungranted repository data on #{page}", :aggregate_failures do
        expect_no_ungranted_data(instance_exec(&path), status)
      end
    end

    it 'never renders ungranted repository data in any week pull request list', :aggregate_failures do
      get repository_week_path(granted_repository, week)
      categories = Capybara.string(response.body).all('.view-prs').pluck('data-category')

      expect(categories).not_to be_empty
      categories.each do |category|
        expect_no_ungranted_data(pr_list_repository_week_path(granted_repository, week, category: category),
                                 :success)
      end
    end
  end
end
