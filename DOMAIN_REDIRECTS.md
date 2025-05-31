# Domain Redirect Configuration

This guide explains how to configure domain redirects for the prmetrics application to ensure smooth transition from old URLs to new ones.

## Overview

With the rebrand from pr-analyzer to prmetrics, we need to ensure:
1. Old Heroku URLs redirect to new ones
2. Future custom domain setup works correctly
3. All variations of domains are handled properly

## Current URLs

### Heroku App URLs
- **Old**: `https://pr-analyzer-production.herokuapp.com`
- **New**: `https://prmetrics-production.herokuapp.com`

### Custom Domain (Already Configured)
- **Primary**: `prmetrics.io` → `symmetrical-rhododendron-p3tpbbm0subpq1m67j2i99n0.herokudns.com`
- **With www**: `www.prmetrics.io` → `shrouded-dogwood-if5v56fe5abdfg8ca8lq9qil.herokudns.com`

## Redirect Configuration

### 1. Heroku Automatic Redirects
Heroku automatically handles redirects from the old app name to the new one for a transition period. This is already active after the rename.

### 2. Application-Level Redirects
To ensure proper handling of all domain variations, we'll add middleware to handle redirects.

### 3. Custom Domain Status
The custom domain is already configured and working:
- ✅ DNS records configured in DNSimple
- ✅ SSL certificates provisioned by Heroku
- ✅ Both prmetrics.io and www.prmetrics.io are active

**Important**: The Heroku DNS targets remain the same even after renaming the app. No DNS changes are needed.

## Environment Variables

After domain setup, these environment variables will be configured:

```bash
ALLOWED_HOSTS=prmetrics.io,www.prmetrics.io,prmetrics-production.herokuapp.com
APPLICATION_HOST=prmetrics.io
DEFAULT_MAILER_SENDER=noreply@prmetrics.io
```

## DNS Configuration (Already Completed)

The following DNS records are already configured in DNSimple:

### For prmetrics.io (root domain)
- **Type**: ALIAS
- **Host**: @ 
- **Target**: `symmetrical-rhododendron-p3tpbbm0subpq1m67j2i99n0.herokudns.com`

### For www.prmetrics.io
- **Type**: CNAME
- **Host**: www
- **Target**: `shrouded-dogwood-if5v56fe5abdfg8ca8lq9qil.herokudns.com`

**Note**: These DNS targets are stable and don't change when renaming the Heroku app.

## SSL Configuration

Heroku automatically provisions SSL certificates via Let's Encrypt once DNS is properly configured. This typically takes 45-60 minutes after DNS propagation.

## Testing Redirects

After configuration, test all URL variations:

```bash
# Test old Heroku URL
curl -I https://pr-analyzer-production.herokuapp.com

# Test new Heroku URL
curl -I https://prmetrics-production.herokuapp.com

# Test custom domain (once configured)
curl -I https://prmetrics.io
curl -I https://www.prmetrics.io

# Test HTTP to HTTPS redirect
curl -I http://prmetrics.io
```

## Monitoring

1. Check Heroku domains status:
   ```bash
   heroku domains
   ```

2. Verify SSL certificate:
   ```bash
   heroku certs:auto
   ```

3. Monitor logs for redirect issues:
   ```bash
   heroku logs --tail | grep redirect
   ```

## Troubleshooting

### Domain not accessible
- Verify DNS propagation (can take 1-48 hours)
- Check `heroku domains` output
- Ensure ALLOWED_HOSTS includes all domain variations

### SSL certificate issues
- Wait for automatic provisioning (45-60 minutes)
- Check `heroku certs:auto` status
- Ensure DNS is correctly configured

### Redirect loops
- Check APPLICATION_HOST environment variable
- Verify force_ssl configuration in production.rb
- Review any custom redirect middleware

## Next Steps

1. ✅ Heroku app renamed (automatic redirects active)
2. ⏳ Configure custom domain when ready
3. ⏳ Update any external services with new URLs
4. ⏳ Monitor redirect performance