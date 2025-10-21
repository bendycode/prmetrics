# frozen_string_literal: true

begin
  require 'rubocop/rake_task'

  RuboCop::RakeTask.new

  namespace :rubocop do
    desc 'Auto-correct RuboCop offenses (safe only)'
    task autocorrect: :environment do
      sh 'bundle exec rubocop -a'
    end

    desc 'Auto-correct all RuboCop offenses (safe and unsafe)'
    task autocorrect_all: :environment do
      sh 'bundle exec rubocop -A'
    end
  end
rescue LoadError
  # RuboCop is unavailable
end
