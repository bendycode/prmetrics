require 'rails_helper'

# The week page's PR panel passes its category straight through to a partial
# whose heading calls titleize on it. Only the categories the controller
# recognizes reach that partial; every other shape, including one Rack parsed
# into an Array or a Hash, gets an empty response instead.
RSpec.describe 'Week PR list category param' do
  let(:user) { create(:user) }
  let(:repository) { create(:repository) }
  let(:week) { create(:week, repository: repository) }
  let(:path) { pr_list_repository_week_path(repository, week) }

  before { sign_in user }

  hostile_categories = {
    'an array' => ['started'],
    'a hash' => { evil: 'started' },
    'an unknown string' => 'abandoned',
    'blank' => ''
  }

  context 'when the controller recognizes the category' do
    let!(:pull_request) do
      create(:pull_request, repository: repository, title: 'Panel row title',
                            gh_created_at: week.begin_date.in_time_zone.noon)
    end

    it 'renders the panel with the category heading and its rows' do
      get path, params: { category: 'started' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Started PRs')
      expect(response.body).to include('Panel row title')
    end

    it 'renders every category the week page links to' do
      %w[started open first_reviewed late stale merged cancelled draft].each do |category|
        get path, params: { category: category }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("#{category.titleize} PRs")
      end
    end

    it 'renders a row whose author is missing' do
      pull_request.author = nil
      pull_request.save(validate: false)

      get path, params: { category: 'started' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Panel row title')
    end

    it 'renders as HTML when the URL carries a format suffix' do
      get "#{path}.json", params: { category: 'started' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Started PRs')
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

    # The policy runs before the category is looked at, so a malformed category on a
    # week the user may not see is refused rather than answered. Were the guard hoisted
    # above authorize, this endpoint would report which weeks exist to a denied user.
    it 'refuses a forbidden week rather than answering for it' do
      deny_policy(RepositoryPolicy, :show?, user, on: repository)

      get path, params: { category: ['started'] }

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq('You are not authorized')
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
