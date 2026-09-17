require 'rails_helper'

# Every GET page a signed-in user can request is visited by a regular user
# who was granted one repository. A second, ungranted repository carries
# marker text in its name, a pull request title, and each contributor's
# username; no page may render it. Numbers leak without text, so aggregate
# totals are checked in repository_list_visibility_spec.rb instead. New GET
# routes must be added to UngrantedRepositoryLeakPages::PAGES, so a page
# added later is checked the same way.
RSpec.describe 'Ungranted repository data never renders' do
  let(:user) { create(:user) }
  let(:week_start) { 2.weeks.ago.beginning_of_week }

  let(:records) do
    repository = create(:repository, name: 'granted/visible')
    hidden_repository = create(:repository, name: "#{UngrantedRepositoryLeakPages::MARKER}/hidden")
    shared_contributor = create(:contributor, username: 'shared-contributor')

    [repository, hidden_repository].each do |repo|
      create(:week, repository: repo, begin_date: week_start, end_date: week_start.end_of_week, week_number: 1)
    end

    hidden_pull_request = create(:pull_request, repository: hidden_repository, title: "#{UngrantedRepositoryLeakPages::MARKER} pull request",
                                                author: create(:contributor, username: "#{UngrantedRepositoryLeakPages::MARKER}-author"),
                                                gh_created_at: week_start + 1.day, ready_for_review_at: week_start + 1.day)
    create(:review, pull_request: hidden_pull_request, author: create(:contributor, username: "#{UngrantedRepositoryLeakPages::MARKER}-reviewer"))
    create(:pull_request_user, pull_request: hidden_pull_request,
                               user: create(:contributor, username: "#{UngrantedRepositoryLeakPages::MARKER}-participant"))
    create(:pull_request_user, pull_request: hidden_pull_request, user: shared_contributor)

    pull_request = create(:pull_request, repository: repository, gh_created_at: week_start + 1.day,
                                         ready_for_review_at: week_start + 1.day)
    review = create(:review, pull_request: pull_request)
    pull_request_user = create(:pull_request_user, pull_request: pull_request, user: shared_contributor)

    {
      repository: repository, hidden_repository: hidden_repository, week: repository.weeks.first,
      pull_request: pull_request, review: review, pull_request_user: pull_request_user,
      shared_contributor: shared_contributor
    }
  end

  before do
    grant_access(user, records[:repository])
    sign_in user
  end

  it 'lists every GET route a signed-in user can request' do
    get_routes = Rails.application.routes.routes.select do |route|
      route.verb.include?('GET') && route.name.present? &&
        !route.defaults[:controller].to_s.start_with?(*UngrantedRepositoryLeakPages::FRAMEWORK_CONTROLLER_PREFIXES)
    end

    expect(UngrantedRepositoryLeakPages::PAGES.keys).to include(*get_routes.map(&:name))
  end

  UngrantedRepositoryLeakPages::PAGES.each do |page, path_for|
    it "never renders ungranted repository data on #{page}" do
      Array(path_for.call(records)).each do |path|
        get path

        expect(response).to have_http_status(:success) unless UngrantedRepositoryLeakPages::PAGES_NOT_RENDERED_FOR_REGULAR_USERS.include?(page)
        expect(response.body.downcase).not_to include(UngrantedRepositoryLeakPages::MARKER), "#{path} rendered ungranted data"
      end
    end
  end
end
