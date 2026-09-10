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

  describe 'a category the controller recognizes' do
    it 'renders the panel with the category heading' do
      get path, params: { category: 'started' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Started PRs')
    end
  end

  describe 'a category the controller does not recognize' do
    {
      'an array' => ['started'],
      'a hash' => { evil: 'started' },
      'an unknown string' => 'abandoned',
      'blank' => ''
    }.each do |shape, value|
      it "renders nothing when the category is #{shape}" do
        get path, params: { category: value }

        expect(response).to have_http_status(:no_content)
        expect(response.body).to be_empty
      end
    end

    it 'renders nothing when the category is absent' do
      get path

      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_empty
    end
  end
end
