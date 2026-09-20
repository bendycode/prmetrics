require 'rails_helper'

RSpec.describe ApplicationController do
  describe '#page_param' do
    controller do
      skip_before_action :authenticate_user!
      skip_after_action :verify_authorized
      skip_after_action :verify_policy_scoped

      def index
        render plain: page_param.inspect
      end
    end

    {
      '1' => 1,
      '2' => 2,
      '000002' => 2,
      '999999' => 999_999,
      '1000000' => nil,
      '0' => nil,
      '-1' => nil,
      '2abc' => nil,
      ' 2' => nil,
      '' => nil,
      ['1'] => nil,
      { a: '1' } => nil
    }.each do |input, expected|
      it "returns #{expected.inspect} for #{input.inspect}" do
        get :index, params: { page: input }

        expect(response.body).to eq(expected.inspect)
      end
    end

    it 'returns nil when page is absent' do
      get :index

      expect(response.body).to eq('nil')
    end
  end

  describe 'authorization enforcement' do
    controller do
      skip_before_action :authenticate_user!
      # PolicyScopingNotPerformedError subclasses AuthorizationNotPerformedError,
      # so the scoping check would satisfy the expectation below on its own.
      skip_after_action :verify_policy_scoped

      def index
        render plain: 'never authorized'
      end

      def show
        authorize :dashboard, :index?
        render plain: 'authorized'
      end
    end

    it 'raises when an action never calls authorize' do
      expect { get :index }.to raise_error(Pundit::AuthorizationNotPerformedError)
    end

    it 'renders when an action calls authorize' do
      get :show, params: { id: 1 }

      expect(response).to have_http_status(:success)
    end
  end

  describe 'policy scoping on list actions' do
    controller do
      def index
        authorize :dashboard, :index?
        policy_scope(Repository) if params[:scoped]
        render plain: 'list'
      end

      def show
        authorize :dashboard, :index?
        render plain: 'single record'
      end
    end

    before { sign_in create(:user) }

    it 'refuses an index action that never applies a policy scope' do
      expect { get :index }.to raise_error(Pundit::PolicyScopingNotPerformedError)
    end

    it 'renders an index action that applies a policy scope' do
      get :index, params: { scoped: true }

      expect(response.body).to eq('list')
    end

    it 'does not require a policy scope on other actions' do
      get :show, params: { id: 1 }

      expect(response.body).to eq('single record')
    end
  end
end
