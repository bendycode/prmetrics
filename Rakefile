# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require_relative 'config/application'

Rails.application.load_tasks

# Rake prerequisites are additive, and rspec-rails hooks `spec` onto `default`
# while the tasks load above. Empty the inherited list first so the order
# declared here is the order that runs: lint in seconds, then the suite.
task(:default).clear_prerequisites
task default: %w[rubocop spec]
