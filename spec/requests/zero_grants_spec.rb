require 'rails_helper'

RSpec.describe 'Pages with no visible repositories' do
  let(:no_access_message) { 'No repositories have been shared with you yet' }

  context 'when the user is a regular user with no grants' do
    before do
      create(:week, repository: create(:repository))
      sign_in create(:user)
    end

    it 'shows the dashboard with a no-access message', :aggregate_failures do
      get dashboard_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(no_access_message)
    end

    it 'shows the repository list with a no-access message and no invitation to add one', :aggregate_failures do
      get repositories_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(no_access_message)
      expect(response.body).not_to include('Add your first repository')
    end
  end

  context 'when the user is an admin and no repositories exist' do
    before { sign_in create(:user, :admin) }

    it 'shows the usual empty dashboard', :aggregate_failures do
      get dashboard_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('No repositories configured yet.')
      expect(response.body).not_to include(no_access_message)
    end
  end
end
