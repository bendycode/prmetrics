# DNSimple Quick Setup - prmetrics.io

## DNS Records to Add in DNSimple

### 1. Root Domain (prmetrics.io)
- **Type**: ALIAS
- **Name**: (leave blank)
- **Content**: `symmetrical-rhododendron-p3tpbbm0subpq1m67j2i99n0.herokudns.com`
- **TTL**: 3600

### 2. WWW Subdomain (www.prmetrics.io)  
- **Type**: CNAME
- **Name**: www
- **Content**: `shrouded-dogwood-if5v56fe5abdfg8ca8lq9qil.herokudns.com`
- **TTL**: 3600

## Steps in DNSimple:
1. Log in to DNSimple
2. Click on prmetrics.io
3. Go to "DNS" → "Manage DNS Records"
4. Click "Add Record" and create the ALIAS record above
5. Click "Add Record" again and create the CNAME record above

## Verify DNS (after 5-10 minutes):
```bash
# Check DNS propagation
dig prmetrics.io
dig www.prmetrics.io

# Or use DNSimple's checker
open https://dnsimple.com/dns-check/prmetrics.io
```

## SSL Certificate:
- Will auto-provision after DNS is configured (45-60 min)
- Check status: `heroku certs:auto`

## Your URLs:
- Production: https://prmetrics.io
- With www: https://www.prmetrics.io  
- Backup: https://pr-analyzer-production-4692dc49e9d6.herokuapp.com

---
✅ Heroku configuration is complete!
📋 Now just add the DNS records above in DNSimple.