require 'rails_helper'

# Heroku runs the release command before every release goes live, which makes
# it the one place a deploy runs migrations; bin/deploy only checks that none
# is left pending.
RSpec.describe 'Procfile' do
  it 'runs schema and data migrations in the release phase' do
    release = Rails.root.join('Procfile').readlines(chomp: true).find { |line| line.start_with?('release:') }

    expect(release).to include('rails db:migrate &&').and include('rails db:migrate:with_data')
  end
end
