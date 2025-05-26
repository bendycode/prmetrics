# DNSimple Setup Guide for prmetrics.io

Congratulations on purchasing prmetrics.io! This guide will walk you through setting it up with your Heroku app using DNSimple.

## Step 1: Add Domain to Heroku

First, let's add your domain to Heroku:

```bash
# Add both root and www versions
heroku domains:add prmetrics.io
heroku domains:add www.prmetrics.io
```

This will return DNS targets that look like:
- `wooden-duck-a5b2c3d4e5.herokudns.com` (example)

Save these DNS targets - you'll need them for Step 2.

## Step 2: Configure DNS in DNSimple

### Option A: Using DNSimple Web Interface

1. Log in to DNSimple
2. Select your prmetrics.io domain
3. Go to DNS > Manage DNS Records
4. Add these records:

#### Root Domain (prmetrics.io)
- **Type**: ALIAS
- **Name**: (leave blank)
- **Content**: Your Heroku DNS target (e.g., wooden-duck-a5b2c3d4e5.herokudns.com)
- **TTL**: 3600

#### WWW Subdomain (www.prmetrics.io)
- **Type**: CNAME
- **Name**: www
- **Content**: Your Heroku DNS target (same as above)
- **TTL**: 3600

### Option B: Using DNSimple CLI

If you have the DNSimple CLI installed:

```bash
# First, get your Heroku DNS target
HEROKU_DNS=$(heroku domains --json | jq -r '.[0].cname')

# Add ALIAS for root domain
dnsimple zones:add-record prmetrics.io \
  --type ALIAS \
  --name "" \
  --content "$HEROKU_DNS" \
  --ttl 3600

# Add CNAME for www
dnsimple zones:add-record prmetrics.io \
  --type CNAME \
  --name "www" \
  --content "$HEROKU_DNS" \
  --ttl 3600
```

## Step 3: Update Heroku Configuration

```bash
# Update allowed hosts
heroku config:set ALLOWED_HOSTS=prmetrics.io,www.prmetrics.io,pr-analyzer-production-4692dc49e9d6.herokuapp.com

# Update application host
heroku config:set APPLICATION_HOST=prmetrics.io

# Update email sender
heroku config:set DEFAULT_MAILER_SENDER=noreply@prmetrics.io
```

## Step 4: Configure Domain Forwarding (Choose One)

### Option 1: Redirect www to root (Recommended)
Add to `config/environments/production.rb`:

```ruby
# Force canonical host to be prmetrics.io (without www)
config.middleware.use Rack::CanonicalHost, 'prmetrics.io' if ENV['RACK_ENV'] == 'production'
```

### Option 2: Redirect root to www
```ruby
# Force canonical host to be www.prmetrics.io
config.middleware.use Rack::CanonicalHost, 'www.prmetrics.io' if ENV['RACK_ENV'] == 'production'
```

You'll need to add the rack-canonical-host gem:
```ruby
# Gemfile
gem 'rack-canonical-host'
```

## Step 5: Email Configuration (Optional)

If you want to send emails from @prmetrics.io addresses:

### Using DNSimple Email Forwarding
1. Go to Email Forwarding in DNSimple
2. Set up forwarding for addresses like:
   - support@prmetrics.io → your-email@gmail.com
   - admin@prmetrics.io → your-email@gmail.com

### For Sending Email
You'll need to verify the domain with your email service:

#### SendGrid (if using Heroku SendGrid addon)
```bash
# The addon will provide instructions for domain verification
heroku addons:open sendgrid
```

#### Other SMTP Providers
Add SPF record in DNSimple:
- **Type**: TXT
- **Name**: (leave blank)
- **Content**: `v=spf1 include:sendgrid.net ~all` (adjust for your provider)

## Step 6: SSL Certificate

Heroku automatically provisions SSL certificates for custom domains. This process:
1. Starts after DNS is properly configured
2. Takes 45-60 minutes
3. Is completely automatic

Check status:
```bash
heroku certs:auto
```

## Step 7: Verify Everything Works

```bash
# Check DNS propagation
dig prmetrics.io
dig www.prmetrics.io

# Test HTTP → HTTPS redirect
curl -I http://prmetrics.io
curl -I http://www.prmetrics.io

# Test final URLs
curl -I https://prmetrics.io
curl -I https://www.prmetrics.io

# Check SSL certificate
echo | openssl s_client -servername prmetrics.io -connect prmetrics.io:443 2>/dev/null | openssl x509 -noout -dates
```

## DNSimple-Specific Features You Can Use

### 1. DNS Templates
Save your configuration as a template for future projects:
1. Go to Account > Templates
2. Create template from prmetrics.io
3. Reuse for similar setups

### 2. API Access
Automate DNS updates in your deployment:
```ruby
# Example: Update DNS via API during deployment
require 'dnsimple'
client = Dnsimple::Client.new(access_token: ENV['DNSIMPLE_TOKEN'])
# ... automated DNS updates
```

### 3. Monitoring
Set up monitoring for your domain:
1. Go to Domain > Monitoring
2. Enable monitoring for prmetrics.io
3. Get alerts if DNS or SSL issues occur

## Troubleshooting

### DNS Not Resolving
- Check records in DNSimple dashboard
- Verify no conflicting records exist
- Wait up to 48 hours for full propagation
- Use `dig @8.8.8.8 prmetrics.io` to check Google's DNS

### SSL Certificate Issues
```bash
# Force certificate refresh
heroku certs:auto:refresh

# Check certificate status
heroku certs:auto
```

### Redirect Loops
- Check CloudFlare is not proxying (if you added it)
- Verify force_ssl is enabled in Rails
- Ensure canonical host middleware is correct

## Timeline
- ✅ Domain purchased
- ⏱️ DNS configuration: 5 minutes
- ⏱️ DNS propagation: 1-48 hours (usually under 1 hour)
- ⏱️ SSL certificate: 45-60 minutes after DNS
- ⏱️ **Total time to fully operational**: 2-4 hours typically

## Quick Setup Script

Run this for automated setup:
```bash
./bin/setup-domain
# Enter: prmetrics.io
# Include www: y
```

## Final Checklist
- [ ] Added prmetrics.io to Heroku
- [ ] Added www.prmetrics.io to Heroku
- [ ] Created ALIAS record for root domain in DNSimple
- [ ] Created CNAME record for www in DNSimple
- [ ] Updated ALLOWED_HOSTS environment variable
- [ ] Updated APPLICATION_HOST environment variable
- [ ] Updated DEFAULT_MAILER_SENDER
- [ ] Waited for DNS propagation
- [ ] Verified SSL certificate is active
- [ ] Tested both HTTP and HTTPS access
- [ ] Configured canonical host redirect

Your app will soon be available at:
- https://prmetrics.io
- https://www.prmetrics.io

The Heroku URL (https://pr-analyzer-production-4692dc49e9d6.herokuapp.com) will continue to work as a backup.