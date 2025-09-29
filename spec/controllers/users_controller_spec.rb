require 'rails_helper'

RSpec.describe UsersController, type: :controller do
  let(:admin_user) { create(:user, :admin) }
  let(:regular_user) { create(:user) }
  let(:other_admin) { create(:user, :admin) }

  before do
    sign_in admin_user
  end

  describe 'GET #index' do
    context 'with admin user' do
      it 'returns http success' do
        get :index
        expect(response).to have_http_status(:success)
      end

      it 'assigns all users ordered by email' do
        user1 = create(:user, email: 'zebra@example.com')
        user2 = create(:user, email: 'alpha@example.com')

        get :index
        expect(assigns(:users)).to match_array([admin_user, user1, user2])
        expect(assigns(:users).map(&:email)).to eq(['alpha@example.com', admin_user.email, 'zebra@example.com'].sort)
      end
    end

    context 'with regular user' do
      before { sign_in regular_user }

      it 'redirects with authorization error' do
        get :index
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('You are not authorized')
      end
    end
  end

  describe 'GET #new' do
    context 'with admin user' do
      it 'returns http success' do
        get :new
        expect(response).to have_http_status(:success)
      end

      it 'assigns a new user' do
        get :new
        expect(assigns(:user)).to be_a_new(User)
      end
    end

    context 'with regular user' do
      before { sign_in regular_user }

      it 'redirects with authorization error' do
        get :new
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('You are not authorized')
      end
    end
  end

  describe 'POST #create' do
    let(:valid_params) { { user: { email: 'newuser@example.com', admin_role_admin: 'regular_user' } } }
    let(:admin_params) { { user: { email: 'newadmin@example.com', admin_role_admin: 'admin' } } }
    let(:invalid_params) { { user: { email: 'invalid-email', admin_role_admin: 'regular_user' } } }

    context 'with admin user' do
      context 'with valid regular user parameters' do
        it 'creates a new regular user' do
          expect {
            post :create, params: valid_params
          }.to change(User, :count).by(1)

          new_user = User.last
          expect(new_user.email).to eq('newuser@example.com')
          expect(new_user.regular_user?).to be true
        end

        it 'redirects to users index with success notice' do
          post :create, params: valid_params
          expect(response).to redirect_to(users_path)
          expect(flash[:notice]).to eq('Invitation sent to newuser@example.com')
        end
      end

      context 'with valid admin parameters' do
        it 'creates a new admin user' do
          expect {
            post :create, params: admin_params
          }.to change(User, :count).by(1)

          new_user = User.last
          expect(new_user.email).to eq('newadmin@example.com')
          expect(new_user.admin?).to be true
        end

        it 'redirects to users index with success notice' do
          post :create, params: admin_params
          expect(response).to redirect_to(users_path)
          expect(flash[:notice]).to eq('Invitation sent to newadmin@example.com')
        end
      end

      context 'with invalid parameters' do
        it 'does not create a user' do
          expect {
            post :create, params: invalid_params
          }.not_to change(User, :count)
        end

        it 'renders new template' do
          post :create, params: invalid_params
          expect(response).to render_template(:new)
        end

        it 'assigns user with errors' do
          post :create, params: invalid_params
          expect(assigns(:user)).to be_present
          expect(assigns(:user).errors).not_to be_empty
        end
      end

      context 'with duplicate email' do
        let!(:existing_user) { create(:user, email: 'existing@example.com') }
        let(:duplicate_params) { { user: { email: 'existing@example.com', admin_role_admin: 'regular_user' } } }

        it 'does not create a user' do
          expect {
            post :create, params: duplicate_params
          }.not_to change(User, :count)
        end

        it 'renders new template with error' do
          post :create, params: duplicate_params
          expect(response).to render_template(:new)
          expect(assigns(:user).errors[:email]).to include('has already been taken')
        end
      end
    end

    context 'with regular user' do
      before { sign_in regular_user }

      it 'redirects with authorization error' do
        post :create, params: valid_params
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('You are not authorized')
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:target_user) { create(:user) }

    context 'with admin user' do
      context 'when deleting a regular user' do
        it 'destroys the user' do
          expect {
            delete :destroy, params: { id: target_user.id }
          }.to change(User, :count).by(-1)
        end

        it 'redirects to users index with success notice' do
          delete :destroy, params: { id: target_user.id }
          expect(response).to redirect_to(users_path)
          expect(flash[:notice]).to eq('User was successfully removed.')
        end
      end

      context 'when deleting another admin (not last)' do
        let!(:another_admin) { create(:user, :admin) }

        it 'destroys the admin user' do
          expect {
            delete :destroy, params: { id: another_admin.id }
          }.to change(User, :count).by(-1)
        end

        it 'redirects with success notice' do
          delete :destroy, params: { id: another_admin.id }
          expect(response).to redirect_to(users_path)
          expect(flash[:notice]).to eq('User was successfully removed.')
        end
      end

      context 'when trying to delete the last admin' do
        before do
          # Make admin_user the only admin by destroying others
          User.admin.where.not(id: admin_user.id).destroy_all
          admin_user.reload
        end

        it 'does not destroy the user' do
          expect {
            delete :destroy, params: { id: admin_user.id }
          }.not_to change(User, :count)
        end

        it 'redirects with authorization error' do
          delete :destroy, params: { id: admin_user.id }
          expect(response).to redirect_to(root_path)
          expect(flash[:alert]).to eq('You are not authorized')
        end
      end

      context 'when deleting a pending invitation' do
        let!(:pending_user) { create(:user, :pending) }

        it 'destroys the pending user' do
          expect {
            delete :destroy, params: { id: pending_user.id }
          }.to change(User, :count).by(-1)
        end

        it 'redirects with success notice' do
          delete :destroy, params: { id: pending_user.id }
          expect(response).to redirect_to(users_path)
          expect(flash[:notice]).to eq('User was successfully removed.')
        end
      end
    end

    context 'with regular user' do
      before { sign_in regular_user }

      it 'redirects with authorization error' do
        delete :destroy, params: { id: target_user.id }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('You are not authorized')
      end
    end
  end

  describe 'private methods' do
    describe '#user_params' do
      controller do
        def test_user_params
          render json: user_params
        end
      end

      before do
        routes.draw { get 'test_user_params' => 'users#test_user_params' }
      end

      context 'when admin_role_admin is "admin"' do
        it 'converts to admin role' do
          get :test_user_params, params: { user: { email: 'test@example.com', admin_role_admin: 'admin' } }
          parsed_response = JSON.parse(response.body)
          expect(parsed_response['role']).to eq('admin')
          expect(parsed_response['email']).to eq('test@example.com')
        end
      end

      context 'when admin_role_admin is not "admin"' do
        it 'converts to regular_user role' do
          get :test_user_params, params: { user: { email: 'test@example.com', admin_role_admin: 'anything_else' } }
          parsed_response = JSON.parse(response.body)
          expect(parsed_response['role']).to eq('regular_user')
        end
      end
    end

    describe '#can_delete_user?' do
      controller do
        def test_can_delete
          set_user
          render json: { can_delete: can_delete_user? }
        end
      end

      before do
        routes.draw { get 'test_can_delete/:id' => 'users#test_can_delete' }
      end

      context 'with pending invitation' do
        let!(:pending_user) { create(:user, :pending) }

        it 'returns true' do
          get :test_can_delete, params: { id: pending_user.id }
          parsed_response = JSON.parse(response.body)
          expect(parsed_response['can_delete']).to be true
        end
      end

      context 'with regular user' do
        it 'returns true' do
          get :test_can_delete, params: { id: regular_user.id }
          parsed_response = JSON.parse(response.body)
          expect(parsed_response['can_delete']).to be true
        end
      end

      context 'with admin user when not last admin' do
        let!(:another_admin) { create(:user, :admin) }

        it 'returns true' do
          get :test_can_delete, params: { id: admin_user.id }
          parsed_response = JSON.parse(response.body)
          expect(parsed_response['can_delete']).to be true
        end
      end

      context 'with last admin user' do
        before do
          User.admin.where.not(id: admin_user.id).destroy_all
        end

        it 'returns false' do
          get :test_can_delete, params: { id: admin_user.id }
          parsed_response = JSON.parse(response.body)
          expect(parsed_response['can_delete']).to be false
        end
      end
    end
  end
end