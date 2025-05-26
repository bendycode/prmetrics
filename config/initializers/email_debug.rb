# Email debugging configuration
# This initializer adds logging to help debug email delivery issues

if Rails.env.production?
  # Log email delivery attempts
  ActionMailer::Base.register_observer(EmailDeliveryObserver)
  
  class EmailDeliveryObserver
    def self.delivered_email(message)
      Rails.logger.info "=" * 50
      Rails.logger.info "Email Delivered:"
      Rails.logger.info "To: #{message.to}"
      Rails.logger.info "Subject: #{message.subject}"
      Rails.logger.info "From: #{message.from}"
      Rails.logger.info "Delivery Method: #{ActionMailer::Base.delivery_method}"
      Rails.logger.info "SMTP Settings: #{ActionMailer::Base.smtp_settings.inspect}"
      Rails.logger.info "=" * 50
    end
  end
  
  # Also log any delivery errors
  ActionMailer::Base.register_interceptor(EmailDeliveryInterceptor)
  
  class EmailDeliveryInterceptor
    def self.delivering_email(message)
      Rails.logger.info "Attempting to deliver email to: #{message.to}"
    end
  end
end