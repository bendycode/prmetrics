require 'rails_helper'

RSpec.describe 'Password reset' do
  let(:user) { create(:user) }
  let(:new_password) { 'a-new-password-456' }

  def request_reset
    post user_password_path, params: { user: { email: user.email } }
  end

  def emailed_token
    ActionMailer::Base.deliveries.last.body.decoded[/reset_password_token=([^"&\s]+)/, 1]
  end

  def reset_password_with(token)
    put user_password_path, params: { user: { reset_password_token: token,
                                              password: new_password, password_confirmation: new_password } }
  end

  it 'emails the address that asked for it' do
    request_reset

    expect(ActionMailer::Base.deliveries).to contain_exactly(have_attributes(to: [user.email]))
  end

  it 'sets a new password from the emailed link' do
    request_reset

    reset_password_with(emailed_token)

    expect(user.reload).to be_valid_password(new_password)
  end

  it 'lets the user sign in with the new password' do
    request_reset
    reset_password_with(emailed_token)
    delete destroy_user_session_path

    post user_session_path, params: { user: { email: user.email, password: new_password } }

    expect(flash[:notice]).to eq(I18n.t('devise.sessions.signed_in'))
  end
end
