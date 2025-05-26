# Email debugging configuration
# This initializer adds logging to help debug email delivery issues

if Rails.env.production? && !Rails.env.test?
  # Define observer classes first
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
  
  class EmailDeliveryInterceptor
    def self.delivering_email(message)
      Rails.logger.info "Attempting to deliver email to: #{message.to}"
    end
  end
  
  # Register observers after classes are defined
  # Wrap in after_initialize to ensure ActionMailer is loaded
  Rails.application.config.after_initialize do
    ActionMailer::Base.register_observer(EmailDeliveryObserver)
    ActionMailer::Base.register_interceptor(EmailDeliveryInterceptor)
  end
end