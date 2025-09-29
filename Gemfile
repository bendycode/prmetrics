source "https://rubygems.org"

ruby "3.4.4"

gem "rails", "~> 7.1.4"

# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem "sprockets-rails"

gem "octokit"
gem "faraday-retry"
gem "kaminari"
gem "bootstrap"
gem "sassc-rails"
gem 'jquery-rails'
gem 'font-awesome-sass'

gem "pg", "~> 1.1"
gem "puma", ">= 5.0"

# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"

# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"

# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"

# Use Redis adapter to run Action Cable in production
gem "redis", ">= 4.0.1"
gem "sidekiq", "~> 7.0"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Authentication
gem "devise", "~> 4.9"
gem "devise_invitable", "~> 2.0"

# Authorization
gem "pundit"

# Data migrations
gem "data_migrate"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri mswin mswin64 mingw x64_mingw ]
  gem 'rspec-rails', '~> 7.1'
  gem 'shoulda-matchers', '~> 6.5'
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'rails-controller-testing'
  gem 'capybara'
  gem 'selenium-webdriver'
end

group :test do
  # Code coverage
  gem 'simplecov', require: false
  gem 'simplecov-console', require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
  
  # Detect N+1 queries
  gem "bullet"
  
  # Preview emails in browser
  gem "letter_opener"
  
  # Process management for development
  gem "foreman"

  # Add speed badges [https://github.com/MiniProfiler/rack-mini-profiler]
  # gem "rack-mini-profiler"

  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"
end

