require 'rails_helper'

RSpec.describe ActionCable::Server::Configuration do
  # Action Cable requires an adapter's file the first time the server needs its
  # pubsub (a subscription or a broadcast), and an adapter that wraps a gem
  # checks that gem's version when its file loads. An environment whose adapter
  # cannot load therefore boots, and fails on its first stream. The app has no
  # streams, so no other example asks for an adapter.
  describe 'built from config/cable.yml' do
    declared = ActiveSupport::ConfigurationFile.parse(Rails.root.join('config/cable.yml')).keys - ['shared']

    (%w[development test production] | declared).each do |environment|
      it "loads the adapter named for #{environment} with the bundled gems" do
        configuration = described_class.new
        configuration.cable = Rails.application.config_for(:cable, env: environment).with_indifferent_access

        expect(configuration.pubsub_adapter).to be < ActionCable::SubscriptionAdapter::Base
      end
    end
  end
end
