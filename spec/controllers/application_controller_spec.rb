require 'rails_helper'

RSpec.describe ApplicationController do
  describe '#page_param' do
    controller do
      skip_before_action :authenticate_user!
      skip_after_action :verify_authorized

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
end
