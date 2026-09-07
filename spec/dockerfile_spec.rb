require 'rails_helper'

RSpec.describe 'Dockerfile' do
  it 'builds with the Ruby version in .ruby-version' do
    pinned = Rails.root.join('Dockerfile').read[/^ARG RUBY_VERSION=(\S+)$/, 1]
    expected = Rails.root.join('.ruby-version').read.strip.delete_prefix('ruby-')

    expect(pinned).to eq(expected)
  end
end
