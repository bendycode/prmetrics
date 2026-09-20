require 'rails_helper'

# Admins invite people through UsersController, which enforces the admin-only
# policy. devise_invitable's own invitation form must not offer a second way in
# that skips it, while invitees still accept through Devise's pages.
RSpec.describe 'Devise invitation routes' do
  let(:regular_user) { create(:user) }

  it 'does not let a signed-in regular user invite someone through devise_invitable', :aggregate_failures do
    sign_in regular_user

    expect { post '/users/invitation', params: { user: { email: 'sneaky@example.com' } } }
      .not_to change(User, :count)
    expect(response).to have_http_status(:not_found)
  end

  it "does not serve devise_invitable's invitation form" do
    sign_in regular_user

    get '/users/invitation/new'

    expect(response).to have_http_status(:not_found)
  end

  it 'still lets an invitee open their acceptance page' do
    invitee = User.invite!(email: 'invitee@example.com', role: :regular_user)

    get accept_user_invitation_path(invitation_token: invitee.raw_invitation_token)

    expect(response).to have_http_status(:success)
  end
end
