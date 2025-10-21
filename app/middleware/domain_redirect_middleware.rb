# frozen_string_literal: true

class DomainRedirectMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)

    # Only redirect in production
    if Rails.env.production?
      host = request.host.downcase

      # Define redirect rules
      redirect_host = case host
      when 'pr-analyzer-production.herokuapp.com'
        'prmetrics-production.herokuapp.com'
      when 'pr-analyzer.herokuapp.com'
        'prmetrics-production.herokuapp.com'
      else
        nil
      end

      # Perform redirect if needed
      if redirect_host
        redirect_url = "#{request.scheme}://#{redirect_host}#{request.fullpath}"
        return [301, { 'Location' => redirect_url, 'Content-Type' => 'text/plain' }, ['Redirecting...']]
      end
    end

    @app.call(env)
  end
end