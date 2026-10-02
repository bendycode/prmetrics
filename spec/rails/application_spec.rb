require 'rails_helper'

RSpec.describe Rails::Application do
  # Production loads every autoloaded file at boot. The test environment does
  # so only when CI is set, so a file whose name and constant disagree would
  # otherwise pass locally and fail in CI or at production boot.
  it 'defines the constant each autoloaded file is named for' do
    expect { Rails.application.eager_load! }.not_to raise_error
  end
end
