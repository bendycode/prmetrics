release: bundle exec rails db:migrate && bundle exec rails db:migrate:with_data
web: bundle exec puma -C config/puma.rb
worker: bundle exec sidekiq -c 2