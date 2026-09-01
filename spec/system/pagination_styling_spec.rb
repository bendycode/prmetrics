require 'rails_helper'

RSpec.describe 'Pagination styling' do
  # Both indexes below paginate at ten per page, and `paginate` renders
  # nothing at all when the collection fits on one page, so each example
  # needs an eleventh record before a paginator exists to inspect.
  let(:per_page) { 10 }
  let(:admin) { create(:user, :admin) }

  before do
    sign_in admin
  end

  # Kaminari's own default partials wrap each page number in a bare
  # <span class="page">, which carries none of the classes Bootstrap's
  # pagination rules select on, so the links render as an unseparated run
  # of digits. The app supplies its own partials under app/views/kaminari/
  # to emit the markup Bootstrap styles. These examples pin that contract:
  # they fail if those partials are removed, or if a Kaminari upgrade
  # changes which partials it renders.
  shared_examples 'a Bootstrap-styled paginator' do
    it 'wraps page links in the classes Bootstrap styles' do
      visit path

      expect(page).to have_css('ul.pagination')
      expect(page).to have_css('ul.pagination li.page-item a.page-link')
    end

    it 'marks the current page without linking it' do
      visit path

      expect(page).to have_css('ul.pagination li.page-item.active')
      expect(page).to have_no_css('ul.pagination span.page')
    end
  end

  describe 'the pull requests index' do
    let(:repository) { create(:repository) }
    let(:path) { repository_pull_requests_path(repository) }

    before do
      create_list(:pull_request, per_page, repository: repository)
      create(:pull_request, repository: repository)
    end

    it_behaves_like 'a Bootstrap-styled paginator'
  end

  describe 'the contributors index' do
    let(:path) { contributors_path }

    before do
      create_list(:contributor, per_page)
      create(:contributor)
    end

    it_behaves_like 'a Bootstrap-styled paginator'
  end
end
