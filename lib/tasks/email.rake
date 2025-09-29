namespace :email do
  desc "Test email configuration by sending a test email"
  task test: :environment do
    email = ENV['TEST_EMAIL'] || 'test@example.com'
    
    puts "Testing email configuration..."
    puts "Delivery method: #{ActionMailer::Base.delivery_method}"
    puts "SMTP settings: #{ActionMailer::Base.smtp_settings.inspect}"
    puts "Sending test email to: #{email}"
    
    begin
      # TODO: Update to use UserMailer or create appropriate test email method
      puts "⚠️ Email task disabled - AdminMailer was removed during Admin->User migration"
      puts "✅ Email configuration check completed (actual sending disabled)"
    rescue => e
      puts "❌ Failed to send email: #{e.message}"
      puts e.backtrace.first(5)
    end
  end
  
  desc "Check email configuration"
  task check_config: :environment do
    puts "=== Email Configuration Check ==="
    puts "Rails Environment: #{Rails.env}"
    puts "Action Mailer Settings:"
    puts "  Delivery Method: #{ActionMailer::Base.delivery_method}"
    puts "  Perform Deliveries: #{ActionMailer::Base.perform_deliveries}"
    puts "  Raise Delivery Errors: #{ActionMailer::Base.raise_delivery_errors}"
    puts "  Default URL Host: #{ActionMailer::Base.default_url_options[:host]}"
    puts "  Default From: #{ENV['DEFAULT_MAILER_SENDER']}"
    
    puts "\nSMTP Configuration:"
    if ENV['SENDGRID_USERNAME'].present?
      puts "  Using SendGrid"
      puts "  Username configured: ✅"
      puts "  Password configured: #{ENV['SENDGRID_PASSWORD'].present? ? '✅' : '❌'}"
    elsif ENV['SMTP_ADDRESS'].present?
      puts "  Using custom SMTP"
      puts "  Address: #{ENV['SMTP_ADDRESS']}"
      puts "  Port: #{ENV['SMTP_PORT'] || 587}"
      puts "  Username configured: #{ENV['SMTP_USERNAME'].present? ? '✅' : '❌'}"
      puts "  Password configured: #{ENV['SMTP_PASSWORD'].present? ? '✅' : '❌'}"
    else
      puts "  ❌ No email configuration found!"
      puts "  Set either SENDGRID_USERNAME/SENDGRID_PASSWORD or SMTP_* variables"
    end
    
    puts "\nApplication Host: #{ENV['APPLICATION_HOST'] || 'Not set (using prmetrics.io)'}"
  end
end