# Heroku Email Setup Guide

## Quick Setup with SendGrid (Recommended)

1. **Add SendGrid add-on to Heroku:**
   ```bash
   heroku addons:create sendgrid:starter
   ```

2. **Verify SendGrid credentials are set:**
   ```bash
   heroku config:grep SENDGRID
   ```

3. **Set the default sender email:**
   ```bash
   heroku config:set DEFAULT_MAILER_SENDER=noreply@prmetrics.io
   ```

4. **Test email configuration:**
   ```bash
   heroku run rake email:check_config
   heroku run rake email:test TEST_EMAIL=your-email@example.com
   ```

## Alternative: Use External SMTP Provider

If you prefer to use your own email service (Gmail, Mailgun, etc.):

```bash
heroku config:set SMTP_ADDRESS=smtp.gmail.com
heroku config:set SMTP_PORT=587
heroku config:set SMTP_DOMAIN=prmetrics.io
heroku config:set SMTP_USERNAME=your-email@gmail.com
heroku config:set SMTP_PASSWORD=your-app-specific-password
heroku config:set DEFAULT_MAILER_SENDER=your-email@gmail.com
```

## Debugging Email Issues

1. **Check current configuration:**
   ```bash
   heroku run rake email:check_config
   ```

2. **View application logs during email send:**
   ```bash
   heroku logs -t
   ```
   Then try to send an invite in another window.

3. **Test email directly:**
   ```bash
   heroku run rails console
   ```
   Then in the console:
   ```ruby
   AdminMailer.with(to: 'test@example.com').test_email.deliver_now
   ```

## Common Issues

### No emails being sent
- Check if SENDGRID_USERNAME or SMTP_ADDRESS is set
- Verify APPLICATION_HOST is set correctly
- Look for errors in logs

### Emails marked as spam
- Ensure DEFAULT_MAILER_SENDER uses your domain
- Set up SPF/DKIM records for your domain
- Use a reputable email service

### "Net::SMTPAuthenticationError"
- Double-check username/password
- For Gmail, use app-specific password, not regular password
- Ensure 2FA is enabled for Gmail

## Monitoring

After setup, monitor email delivery:
```bash
# View recent logs
heroku logs --tail --source app --ps web

# Check for email-related errors
heroku logs --source app | grep -i mail
```