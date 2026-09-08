require 'rails_helper'

# Devise's controllers inherit ApplicationController, so they would fall
# under verify_authorized without the devise_controller? exemption.
RSpec.describe 'Devise Authorization Exemption' do
  it 'renders the sign-in page for a signed-out visitor' do
    get new_user_session_path

    expect(response).to have_http_status(:success)
  end
end
