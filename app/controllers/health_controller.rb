class HealthController < ApplicationController
  skip_before_action :authenticate_user!, only: [:show]

  def show
    health_status = check_health_status

    if health_status[:status] == 'ok'
      render json: health_status, status: :ok
    else
      render json: health_status, status: :service_unavailable
    end
  end

  private

  def check_health_status
    status = {
      status: 'ok',
      timestamp: Time.current.iso8601,
      services: {}
    }

    # Check database connection
    status[:services][:database] = check_database

    # Check Redis/Sidekiq connection
    status[:services][:redis] = check_redis

    # Check GitHub API (optional, might want to disable in production to save API calls)
    # status[:services][:github] = check_github_api

    # Overall status
    if status[:services].values.any? { |s| s[:status] != 'ok' }
      status[:status] = 'error'
    end

    status
  end

  def check_database
    ActiveRecord::Base.connection.execute('SELECT 1')
    { status: 'ok', message: 'Database connection successful' }
  rescue StandardError => e
    { status: 'error', message: "Database connection failed: #{e.message}" }
  end

  def check_redis
    redis_url = ENV['REDIS_URL'] || 'redis://localhost:6379/0'
    redis_config = { url: redis_url }

    # Handle Heroku Redis SSL
    if redis_url.start_with?('rediss://')
      redis_config[:ssl_params] = { verify_mode: OpenSSL::SSL::VERIFY_NONE }
    end

    redis = Redis.new(redis_config)
    redis.ping
    { status: 'ok', message: 'Redis connection successful' }
  rescue StandardError => e
    { status: 'error', message: "Redis connection failed: #{e.message}" }
  ensure
    redis&.close
  end

  def check_github_api
    client = Octokit::Client.new(access_token: ENV['GITHUB_ACCESS_TOKEN'])
    rate_limit = client.rate_limit
    {
      status: 'ok',
      message: 'GitHub API accessible',
      rate_limit_remaining: rate_limit.remaining,
      rate_limit_reset: rate_limit.resets_at
    }
  rescue StandardError => e
    { status: 'error', message: "GitHub API check failed: #{e.message}" }
  end
end
