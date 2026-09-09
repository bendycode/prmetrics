require 'rails_helper'

# The Sidekiq web UI is mounted behind Devise's route-level authenticate with
# an admin lambda. When the lambda fails the route constraint fails, so a
# signed-in regular user gets a 404 rather than the "You are not authorized"
# redirect every controller-level denial produces. Sidekiq's index reads Redis
# for its stats, so the admin example stubs the engine and proves only that
# the constraint lets an admin through.
RSpec.describe 'Sidekiq Authorization' do
  describe 'GET /sidekiq' do
    it 'reaches the Sidekiq web UI for an admin' do
      allow(Sidekiq::Web).to receive(:call).and_return([200, { 'content-type' => 'text/plain' }, ['ok']])
      sign_in create(:user, :admin)

      get '/sidekiq'

      expect(response).to have_http_status(:success)
      expect(Sidekiq::Web).to have_received(:call)
    end

    it 'answers 404 for a signed-in regular user' do
      sign_in create(:user, role: :regular_user)

      get '/sidekiq'

      expect(response).to have_http_status(:not_found)
    end

    # After a request to the mount the route helpers carry its script name, so
    # new_user_session_path would read /sidekiq/users/sign_in here.
    it 'redirects a signed-out visitor to sign in' do
      get '/sidekiq'

      expect(response).to redirect_to('/users/sign_in')
    end
  end
end
