require 'rails_helper'

RSpec.describe Admin, 'invitations', type: :model do
  describe 'devise invitable' do
    it 'can be invited' do
      admin = Admin.invite!(email: 'newadmin@example.com')
      
      expect(admin).to be_persisted
      expect(admin.invitation_token).to be_present
      expect(admin.invitation_sent_at).to be_present
      expect(admin).not_to be_invitation_accepted
    end
    
    it 'can accept invitation' do
      admin = Admin.invite!(email: 'newadmin@example.com')
      
      # Set password and accept invitation
      admin.password = 'newpassword123'
      admin.password_confirmation = 'newpassword123'
      admin.accept_invitation!
      
      expect(admin).to be_invitation_accepted
      expect(admin.invitation_accepted_at).to be_present
      expect(admin.valid_password?('newpassword123')).to be true
    end
    
    it 'tracks who invited the admin' do
      inviter = create(:admin)
      admin = Admin.invite!({ email: 'newadmin@example.com' }, inviter)
      
      expect(admin.invited_by).to eq(inviter)
    end
  end
end