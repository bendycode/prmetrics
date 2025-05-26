# Custom Domain Setup Guide

## Recommended Domain Names

Based on your app's functionality, here are some domain suggestions:

### Top Recommendations
1. **prmetrics.io** - Clear, professional, focuses on metrics
2. **pullstats.com** - Short, descriptive, easy to remember
3. **reviewpulse.io** - Suggests monitoring/tracking reviews
4. **mergetrack.com** - Emphasizes tracking merge performance
5. **prinsights.io** - "PR Insights" - professional and clear

### Why these work well:
- They're short and memorable
- They describe what the app does
- .io domains are popular for developer tools
- They're likely to be available

## Step-by-Step Domain Setup

### 1. Purchase Your Domain
Popular registrars:
- **Namecheap** - Good prices, free WHOIS privacy
- **Google Domains** - Simple interface, good DNS management
- **Cloudflare** - At-cost domains, great DNS features
- **Porkbun** - Competitive prices, good support

### 2. Add Domain to Heroku

```bash
# Add both root and www versions
heroku domains:add yourdomain.com
heroku domains:add www.yourdomain.com

# This will give you DNS targets like:
# wooden-duck-a5b2c3d4e5.herokudns.com
```

### 3. Configure DNS Records

In your domain registrar's DNS settings, add:

#### For Root Domain (yourdomain.com)
- **Type**: ALIAS, ANAME, or CNAME (depends on registrar)
- **Name**: @ or blank
- **Target**: Your Heroku DNS target

#### For WWW Subdomain (www.yourdomain.com)
- **Type**: CNAME
- **Name**: www
- **Target**: Your Heroku DNS target

#### Example DNS Configuration:
```
Type    Host    Value
ALIAS   @       wooden-duck-a5b2c3d4e5.herokudns.com
CNAME   www     wooden-duck-a5b2c3d4e5.herokudns.com
```

### 4. Enable SSL

Heroku provides free automated SSL certificates:

```bash
# SSL is automatically provisioned for custom domains
# Check status with:
heroku certs:auto
```

### 5. Update Your Rails Configuration

```bash
# Update allowed hosts
heroku config:set ALLOWED_HOSTS=yourdomain.com,www.yourdomain.com,pr-analyzer-production-4692dc49e9d6.herokuapp.com

# Update application host
heroku config:set APPLICATION_HOST=yourdomain.com
```

### 6. Set Up Domain Redirects (Optional)

Force www or non-www (choose one):

#### Force WWW in Rails
Add to `config/environments/production.rb`:
```ruby
config.force_ssl = true
config.middleware.use Rack::CanonicalHost, 'www.yourdomain.com'
```

#### Or Force Non-WWW
```ruby
config.middleware.use Rack::CanonicalHost, 'yourdomain.com'
```

### 7. Update Email Configuration

```bash
# Update mailer settings
heroku config:set DEFAULT_MAILER_SENDER=noreply@yourdomain.com

# If using custom SMTP, update domain
heroku config:set SMTP_DOMAIN=yourdomain.com
```

## DNS Propagation

- DNS changes can take 1-48 hours to propagate
- You can check propagation at: https://www.whatsmydns.net/
- Your site will remain accessible at the Heroku URL during this time

## Testing Your Domain

```bash
# Check DNS resolution
dig yourdomain.com
dig www.yourdomain.com

# Test HTTPS
curl -I https://yourdomain.com
curl -I https://www.yourdomain.com

# Check certificate
openssl s_client -connect yourdomain.com:443 -servername yourdomain.com
```

## Troubleshooting

### "Host not found" error
- Wait for DNS propagation
- Verify DNS records are correct
- Check you added both domains to Heroku

### SSL Certificate errors
- Run `heroku certs:auto:refresh`
- Ensure domains are verified: `heroku domains`
- Wait up to 45 minutes for cert provisioning

### Redirect loops
- Check force_ssl setting
- Verify CloudFlare SSL mode (if using CloudFlare)
- Ensure canonical host middleware is configured correctly

## Using CloudFlare (Optional but Recommended)

CloudFlare provides:
- Free CDN and caching
- DDoS protection
- Advanced analytics
- Page rules for redirects

Setup:
1. Add site to CloudFlare
2. Update nameservers at registrar
3. Set SSL mode to "Full"
4. Create page rule for WWW redirect
5. Enable "Always Use HTTPS"

## Final Checklist

- [ ] Domain purchased and verified
- [ ] Both root and www domains added to Heroku
- [ ] DNS records configured
- [ ] SSL certificate active
- [ ] ALLOWED_HOSTS updated
- [ ] APPLICATION_HOST updated
- [ ] Email sender domain updated
- [ ] Canonical host redirect configured
- [ ] Tested both HTTP and HTTPS access
- [ ] Verified no redirect loops
- [ ] Updated any hardcoded URLs in the app

## Estimated Timeline

1. **Domain purchase**: 5 minutes
2. **Heroku setup**: 10 minutes
3. **DNS configuration**: 15 minutes
4. **DNS propagation**: 1-48 hours
5. **SSL provisioning**: 45 minutes
6. **Total active time**: ~30 minutes

## Cost Considerations

- **Domain**: $10-15/year for .com, $25-35/year for .io
- **Heroku SSL**: Free with ACM (Automated Certificate Management)
- **CloudFlare**: Free tier is sufficient
- **Total additional cost**: Just the domain registration