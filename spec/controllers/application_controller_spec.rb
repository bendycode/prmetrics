require 'rails_helper'

RSpec.describe ApplicationController do
  describe '#page_param' do
    controller do
      skip_before_action :authenticate_user!

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
end
