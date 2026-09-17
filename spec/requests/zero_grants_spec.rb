require 'rails_helper'

# A regular user with no granted repositories sees empty pages that say
# access has not been granted, rather than pages that look broken.
RSpec.describe 'A regular user with no granted repositories' do
  let(:no_access_message) { 'No repositories have been shared with you yet' }

  before do
    create(:week, repository: create(:repository))
    sign_in create(:user)
  end

  it 'sees the dashboard with a no-access message', :aggregate_failures do
    get dashboard_path

    expect(response).to have_http_status(:success)
    expect(response.body).to include(no_access_message)
  end

  it 'sees the repository list with a no-access message', :aggregate_failures do
    get repositories_path

    expect(response).to have_http_status(:success)
    expect(response.body).to include(no_access_message)
  end

  it 'is not told to add a repository' do
    get repositories_path

    expect(response.body).not_to include('Add your first repository')
  end

  context 'when the user is an admin and no repositories exist' do
    before do
      Repository.destroy_all
      sign_in create(:user, :admin)
    end

    it 'sees the usual empty state instead', :aggregate_failures do
      get dashboard_path

      expect(response.body).to include('No repositories configured yet.')
      expect(response.body).not_to include(no_access_message)
    end
  end
end
