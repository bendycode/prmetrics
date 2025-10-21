namespace :domain do
  desc "Check domain redirect configuration"
  task check_redirects: :environment do
    puts "🔍 Domain Redirect Configuration Check"
    puts "====================================="
    puts ""

    # Check environment variables
    puts "📋 Environment Variables:"
    puts "  APPLICATION_HOST: #{ENV['APPLICATION_HOST'] || '(not set)'}"
    puts "  ALLOWED_HOSTS: #{ENV['ALLOWED_HOSTS'] || '(not set)'}"
    puts "  DEFAULT_MAILER_SENDER: #{ENV['DEFAULT_MAILER_SENDER'] || '(not set)'}"
    puts ""

    # Check middleware
    puts "🔧 Middleware Configuration:"
    middleware_loaded = Rails.application.config.middleware.any? { |m| m.to_s.include?('DomainRedirectMiddleware') }
    puts "  DomainRedirectMiddleware: #{middleware_loaded ? '✅ Loaded' : '❌ Not loaded'}"
    puts ""

    # Check force SSL
    puts "🔒 SSL Configuration:"
    puts "  Force SSL: #{Rails.application.config.force_ssl ? '✅ Enabled' : '❌ Disabled'}"
    puts ""

    puts "✅ Configuration check complete!"
  end

  desc "List all configured domains on Heroku"
  task list_domains: :environment do
    puts "📋 Fetching Heroku domains..."
    system("heroku domains")
  end
end
