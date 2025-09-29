require 'rails_helper'

RSpec.describe HealthController, type: :controller do
  describe "GET #show" do
    context "without authentication" do
      it "returns http success without requiring authentication" do
        get :show
        expect(response).to have_http_status(:success)
      end

      it "returns JSON with health status" do
        get :show
        expect(response.content_type).to include('application/json')
      end

      it "includes required health check fields" do
        get :show
        parsed_response = JSON.parse(response.body)

        expect(parsed_response).to have_key('status')
        expect(parsed_response).to have_key('timestamp')
        expect(parsed_response).to have_key('services')
        expect(parsed_response['services']).to have_key('database')
        expect(parsed_response['services']).to have_key('redis')
      end
    end

    context "when all services are healthy" do
      before do
        allow(ActiveRecord::Base.connection).to receive(:execute).with('SELECT 1')

        redis_mock = instance_double(Redis)
        allow(Redis).to receive(:new).and_return(redis_mock)
        allow(redis_mock).to receive(:ping)
        allow(redis_mock).to receive(:close)
      end

      it "returns ok status" do
        get :show
        parsed_response = JSON.parse(response.body)

        expect(parsed_response['status']).to eq('ok')
        expect(response).to have_http_status(:ok)
      end

      it "reports all services as ok" do
        get :show
        parsed_response = JSON.parse(response.body)

        expect(parsed_response['services']['database']['status']).to eq('ok')
        expect(parsed_response['services']['redis']['status']).to eq('ok')
      end
    end

    context "when database is unhealthy" do
      before do
        allow(ActiveRecord::Base.connection).to receive(:execute).with('SELECT 1').and_raise(StandardError.new('Connection failed'))

        redis_mock = instance_double(Redis)
        allow(Redis).to receive(:new).and_return(redis_mock)
        allow(redis_mock).to receive(:ping)
        allow(redis_mock).to receive(:close)
      end

      it "returns error status" do
        get :show
        parsed_response = JSON.parse(response.body)

        expect(parsed_response['status']).to eq('error')
        expect(response).to have_http_status(:service_unavailable)
      end

      it "reports database as error" do
        get :show
        parsed_response = JSON.parse(response.body)

        expect(parsed_response['services']['database']['status']).to eq('error')
        expect(parsed_response['services']['database']['message']).to include('Connection failed')
        expect(parsed_response['services']['redis']['status']).to eq('ok')
      end
    end

    context "when redis is unhealthy" do
      before do
        allow(ActiveRecord::Base.connection).to receive(:execute).with('SELECT 1')

        redis_mock = instance_double(Redis)
        allow(Redis).to receive(:new).and_return(redis_mock)
        allow(redis_mock).to receive(:ping).and_raise(StandardError.new('Redis unavailable'))
        allow(redis_mock).to receive(:close)
      end

      it "returns error status" do
        get :show
        parsed_response = JSON.parse(response.body)

        expect(parsed_response['status']).to eq('error')
        expect(response).to have_http_status(:service_unavailable)
      end

      it "reports redis as error" do
        get :show
        parsed_response = JSON.parse(response.body)

        expect(parsed_response['services']['database']['status']).to eq('ok')
        expect(parsed_response['services']['redis']['status']).to eq('error')
        expect(parsed_response['services']['redis']['message']).to include('Redis unavailable')
      end
    end

    context "callback configuration regression prevention" do
      it "verifies authenticate_user! method exists (prevents authenticate_admin! typo)" do
        # This test prevents the regression where someone might use authenticate_admin!
        # instead of authenticate_user! in the skip_before_action call
        # If authenticate_user! doesn't exist, the app would crash on startup

        expect(ApplicationController.instance_methods).to include(:authenticate_user!)
        expect(ApplicationController.instance_methods).not_to include(:authenticate_admin!)
      end

      it "confirms the health endpoint is accessible without authentication" do
        # This test serves as a regression guard: if the callback skip was broken,
        # this test would fail because it would try to redirect to login
        get :show
        expect(response).not_to be_redirect
        expect(response).to have_http_status(:success)
        expect(response.content_type).to include('application/json')
      end
    end
  end

  describe "health check methods" do
    let(:controller) { HealthController.new }

    describe "#check_database" do
      it "returns ok status when database is accessible" do
        allow(ActiveRecord::Base.connection).to receive(:execute).with('SELECT 1')

        result = controller.send(:check_database)
        expect(result[:status]).to eq('ok')
        expect(result[:message]).to include('successful')
      end

      it "returns error status when database is not accessible" do
        allow(ActiveRecord::Base.connection).to receive(:execute).with('SELECT 1').and_raise(StandardError.new('Connection failed'))

        result = controller.send(:check_database)
        expect(result[:status]).to eq('error')
        expect(result[:message]).to include('Connection failed')
      end
    end

    describe "#check_redis" do
      it "returns ok status when redis is accessible" do
        redis_mock = instance_double(Redis)
        allow(Redis).to receive(:new).and_return(redis_mock)
        allow(redis_mock).to receive(:ping)
        allow(redis_mock).to receive(:close)

        result = controller.send(:check_redis)
        expect(result[:status]).to eq('ok')
        expect(result[:message]).to include('successful')
      end

      it "returns error status when redis is not accessible" do
        redis_mock = instance_double(Redis)
        allow(Redis).to receive(:new).and_return(redis_mock)
        allow(redis_mock).to receive(:ping).and_raise(StandardError.new('Redis down'))
        allow(redis_mock).to receive(:close)

        result = controller.send(:check_redis)
        expect(result[:status]).to eq('error')
        expect(result[:message]).to include('Redis down')
      end

      it "handles SSL configuration for Heroku Redis" do
        allow(ENV).to receive(:[]).with('REDIS_URL').and_return('rediss://user:pass@host:port/0')

        expected_config = {
          url: 'rediss://user:pass@host:port/0',
          ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE }
        }

        expect(Redis).to receive(:new).with(expected_config).and_return(instance_double(Redis, ping: true, close: true))

        controller.send(:check_redis)
      end
    end
  end
end