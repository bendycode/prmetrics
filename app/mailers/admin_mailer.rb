class AdminMailer < ApplicationMailer
  def test_email
    @recipient = params[:to]
    @sent_at = Time.current
    
    mail(
      to: @recipient,
      subject: 'PR Metrics - Test Email'
    )
  end
end