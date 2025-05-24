require 'rails_helper'

RSpec.describe AdminsController, type: :controller do
  let(:admin) { create(:admin) }
  
  before do
    sign_in admin
  end

  describe "GET #index" do
    it "returns http success" do
      get :index
      expect(response).to have_http_status(:success)
    end
    
    it "assigns all admins" do
      other_admin = create(:admin)
      get :index
      expect(assigns(:admins)).to match_array([admin, other_admin])
    end
  end

  describe "GET #new" do
    it "returns http success" do
      get :new
      expect(response).to have_http_status(:success)
    end
    
    it "assigns a new admin" do
      get :new
      expect(assigns(:admin)).to be_a_new(Admin)
    end
  end

  describe "POST #create" do
    context "with valid params" do
      it "creates a new Admin invitation" do
        expect {
          post :create, params: { admin: { email: 'newadmin@example.com' } }
        }.to change(Admin, :count).by(1)
      end
      
      it "redirects to admins list" do
        post :create, params: { admin: { email: 'newadmin@example.com' } }
        expect(response).to redirect_to(admins_path)
      end
      
      it "sets the inviter as current admin" do
        post :create, params: { admin: { email: 'newadmin@example.com' } }
        new_admin = Admin.last
        expect(new_admin.invited_by).to eq(admin)
      end
    end
    
    context "with invalid params" do
      it "renders new template" do
        post :create, params: { admin: { email: '' } }
        expect(response).to render_template(:new)
      end
    end
  end

  describe "DELETE #destroy" do
    let!(:other_admin) { create(:admin) }
    
    context "when deleting another admin" do
      it "destroys the admin" do
        expect {
          delete :destroy, params: { id: other_admin.id }
        }.to change(Admin, :count).by(-1)
      end
      
      it "redirects to admins list" do
        delete :destroy, params: { id: other_admin.id }
        expect(response).to redirect_to(admins_path)
      end
    end
    
    context "when trying to delete the last active admin" do
      let!(:pending_admin) { Admin.invite!(email: 'pending@example.com') }
      
      before do
        # Make sure only one admin is active
        other_admin.destroy
      end
      
      it "does not destroy the admin" do
        expect {
          delete :destroy, params: { id: admin.id }
        }.not_to change(Admin, :count)
      end
      
      it "redirects with alert" do
        delete :destroy, params: { id: admin.id }
        expect(response).to redirect_to(admins_path)
        expect(flash[:alert]).to eq('Cannot delete the last admin.')
      end
    end
    
    context "when deleting a pending invitation" do
      let!(:pending_admin) { Admin.invite!(email: 'pending@example.com') }
      
      it "destroys the pending admin" do
        expect {
          delete :destroy, params: { id: pending_admin.id }
        }.to change(Admin, :count).by(-1)
      end
    end
  end
end