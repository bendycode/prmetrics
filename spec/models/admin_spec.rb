require 'rails_helper'

RSpec.describe Admin, type: :model do
  describe 'validations' do
    it 'requires an email' do
      admin = Admin.new(password: 'password123')
      expect(admin).not_to be_valid
      expect(admin.errors[:email]).to include("can't be blank")
    end
    
    it 'requires a unique email' do
      create(:admin, email: 'test@example.com')
      admin = build(:admin, email: 'test@example.com')
      expect(admin).not_to be_valid
      expect(admin.errors[:email]).to include("has already been taken")
    end
    
    it 'requires a password' do
      admin = Admin.new(email: 'test@example.com')
      expect(admin).not_to be_valid
      expect(admin.errors[:password]).to include("can't be blank")
    end
  end
  
  describe 'factory' do
    it 'creates a valid admin' do
      admin = build(:admin)
      expect(admin).to be_valid
    end
  end
end