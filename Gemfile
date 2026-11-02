source 'https://rubygems.org'

ruby '3.4.9'

gem 'rails', '~> 7.2.3'

# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem 'sprockets-rails'

gem 'bootstrap'
gem 'faraday'
gem 'faraday-retry'
gem 'font-awesome-sass'
gem 'jquery-rails'
# TODO(PRM-134): Move to json 3 on purpose -- this constraint is what keeps a bump
# of a gem depending on json from moving it. json 3 raises on two options gems pass:
# - quirks_mode, from Active Support. Rails 7.2.4 drops it but cannot resolve with
#   Sidekiq 8.1 (connection_pool), so Rails 8.1 is the first usable release.
# - create_additions, from Sprockets before 4.3, when it reads a manifest already
#   on disk. Specs pass while production asset lookup and a second
#   assets:precompile raise, so move Sprockets before lifting this.
gem 'json', '< 3'
gem 'kaminari'
gem 'octokit'
gem 'sassc-rails'

gem 'pg'
gem 'puma'

# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem 'importmap-rails'

# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem 'turbo-rails'

# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem 'stimulus-rails'

# Use Redis adapter to run Action Cable in production
gem 'redis'
gem 'sidekiq', '~> 8.1'

# Data migrations - run after schema migrations for backfilling
gem 'data_migrate'

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Authentication
gem 'devise', '~> 5.0'
gem 'devise_invitable', '~> 2.0'

# Authorization
gem 'pundit'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'capybara'
  gem 'debug', platforms: %i[mri mswin mswin64 mingw x64_mingw]
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'rails-controller-testing'
  gem 'rspec-rails', '~> 8.0'
  gem 'selenium-webdriver'
  gem 'shoulda-matchers', '~> 8.0'
end

group :test do
  # Code coverage
  gem 'simplecov', require: false
  gem 'simplecov-console', require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem 'web-console'

  # Detect N+1 queries
  gem 'bullet'

  # Preview emails in browser
  gem 'letter_opener'

  # Process management for development
  gem 'foreman'

  # Code quality and linting
  gem 'rubocop', require: false
  gem 'rubocop-capybara', require: false
  gem 'rubocop-factory_bot', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec', require: false
  gem 'rubocop-rspec_rails', require: false

  # Add speed badges [https://github.com/MiniProfiler/rack-mini-profiler]
  # gem "rack-mini-profiler"

  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"
end
