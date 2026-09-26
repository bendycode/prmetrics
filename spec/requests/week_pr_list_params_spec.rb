require 'rails_helper'

# The week page's PR panel passes its category straight through to a partial whose
# heading calls titleize on it. Only the categories the controller recognizes reach that
# partial; every other shape, including one Rack parsed into an Array or a Hash, gets an
# empty response instead.
RSpec.describe 'Week PR list category param' do
  let(:user) { create(:user) }
  let(:repository) { create(:repository) }
  let(:week) { create(:week, repository: repository) }
  let(:path) { pr_list_repository_week_path(repository, week) }

  before do
    grant_access(user, repository)
    sign_in user
  end

  hostile_categories = {
    'an array' => ['started'],
    'a hash' => { evil: 'started' },
    'an unknown string' => 'abandoned',
    'blank' => ''
  }

  context 'when the controller recognizes the category' do
    # One pull request per category, each titled distinctly, so an example can say both
    # which rows a category must show and which it must not. Asserting the heading alone
    # would prove nothing: the partial builds it by calling titleize on the same param
    # the request sent, so it matches whatever scope the controller actually loaded.
    let(:inside_week) { week.begin_date.in_time_zone + 12.hours }

    let!(:open_pr) do
      create(:pull_request, repository: repository, title: 'Still open this week', gh_created_at: inside_week)
    end

    before do
      create(:pull_request, :draft, repository: repository, title: 'Draft this week', gh_created_at: inside_week)
      create(:pull_request, :with_week_associations, repository: repository,
                                                     title: 'Merged this week',
                                                     gh_created_at: inside_week,
                                                     gh_merged_at: inside_week, merged_week: week)
      create(:pull_request, :with_week_associations, repository: repository,
                                                     title: 'Cancelled this week',
                                                     gh_created_at: inside_week,
                                                     gh_closed_at: inside_week, closed_week: week)
      create(:pull_request, :with_week_associations, repository: repository,
                                                     title: 'First reviewed this week',
                                                     gh_created_at: inside_week,
                                                     first_review_week: week)
      create(:pull_request, :with_week_associations, repository: repository,
                                                     title: 'Approved this week',
                                                     gh_created_at: inside_week,
                                                     first_approval_week: week)
      create(:pull_request, :approved_before_week_end, repository: repository,
                                                       title: 'Approved ten days before',
                                                       week: week, days_before_week_end: 10)
      create(:pull_request, :approved_before_week_end, repository: repository,
                                                       title: 'Approved forty days before',
                                                       week: week, days_before_week_end: 40)
    end

    {
      'started' => { shows: ['Still open this week', 'Draft this week', 'Merged this week',
                             'Cancelled this week', 'First reviewed this week'],
                     hides: ['Approved ten days before', 'Approved forty days before'] },
      'open' => { shows: ['Still open this week', 'Merged this week', 'First reviewed this week',
                          'Approved ten days before', 'Approved forty days before'],
                  hides: ['Draft this week', 'Cancelled this week'] },
      'first_feedback' => { shows: ['First reviewed this week'],
                            hides: ['Still open this week', 'Merged this week', 'Approved this week'] },
      'approved' => { shows: ['Approved this week'],
                      hides: ['Still open this week', 'First reviewed this week'] },
      'late' => { shows: ['Approved ten days before'],
                  hides: ['Approved forty days before', 'Still open this week'] },
      'stale' => { shows: ['Approved forty days before'],
                   hides: ['Approved ten days before', 'Still open this week'] },
      'merged' => { shows: ['Merged this week'],
                    hides: ['Cancelled this week', 'Still open this week'] },
      'cancelled' => { shows: ['Cancelled this week'],
                       hides: ['Merged this week', 'Still open this week'] },
      'draft' => { shows: ['Draft this week'],
                   hides: ['Still open this week', 'Merged this week'] }
    }.tap { |table| it('covers every category the week page offers') { expect(table.keys).to match_array(WeeksController::PR_LISTS.keys) } }
     .each do |category, rows|
      it "loads the #{category} scope" do
        get path, params: { category: category }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("#{category.titleize} PRs")
        rows[:shows].each { |title| expect(response.body).to include(title) }
        rows[:hides].each { |title| expect(response.body).not_to include(title) }
      end
    end

    it 'renders a row whose author is missing' do
      open_pr.author = nil
      open_pr.save(validate: false)

      get path, params: { category: 'started' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Still open this week')
    end

    it 'refuses a format it cannot serve rather than answering it as HTML' do
      get "#{path}.json", params: { category: 'started' }

      expect(response).to have_http_status(:not_acceptable)
    end

    it 'serves the panel as HTML' do
      get path, params: { category: 'started' }

      expect(response.media_type).to eq('text/html')
    end
  end

  context 'when the controller does not recognize the category' do
    hostile_categories.each do |shape, value|
      it "renders nothing when the category is #{shape}" do
        get path, params: { category: value }

        expect(response).to have_http_status(:no_content)
        expect(response.body).to be_empty
      end
    end

    # The week is found through the user's granted repositories before the category is looked
    # at, so a malformed category on a week the user may not see answers as a missing week
    # does. Were the guard hoisted above the lookup, this endpoint would report which weeks
    # exist to a user who was not granted their repository.
    it 'answers a week in an ungranted repository as not found' do
      hidden_week = create(:week, repository: create(:repository))

      get pr_list_repository_week_path(hidden_week.repository, hidden_week), params: { category: ['started'] }

      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when no category is given at all' do
    it 'renders nothing' do
      get path

      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_empty
    end
  end
end
