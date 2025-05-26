class ApplicationMailer < ActionMailer::Base
  default from: ENV['DEFAULT_MAILER_SENDER'] || 'noreply@prmetrics.io'
  layout "mailer"
end
