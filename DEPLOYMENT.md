# Deployment Checklist

This checklist ensures a smooth deployment of the PR Analyzer application to production.

## Pre-Deployment

### 1. Environment Variables
- [ ] Copy `.env.example` to `.env` on production server
- [ ] Set `GITHUB_ACCESS_TOKEN` with appropriate permissions
- [ ] Set `DEFAULT_MAILER_SENDER` to your email address
- [ ] Configure `REDIS_URL` for your Redis instance
- [ ] Set `DATABASE_URL` or individual DB configuration
- [ ] Set `APPLICATION_HOST` to your domain
- [ ] Set `ALLOWED_HOSTS` with comma-separated list of allowed domains
- [ ] Generate and set `SECRET_KEY_BASE` using `rails secret`
- [ ] Configure SMTP settings if sending emails

### 2. Database Setup
- [ ] Create production database
- [ ] Run `rails db:migrate RAILS_ENV=production`
- [ ] Create initial admin user (via console or invitation)

### 3. Asset Compilation
- [ ] Run `rails assets:precompile RAILS_ENV=production`
- [ ] Ensure assets are served properly (check nginx/apache config)

### 4. Background Jobs
- [ ] Ensure Redis is running
- [ ] Configure Sidekiq systemd service or supervisor
- [ ] Test Sidekiq connectivity

### 5. Web Server Configuration
- [ ] Configure nginx/apache to proxy to Rails app
- [ ] Set up SSL certificates (Let's Encrypt recommended)
- [ ] Configure static file serving
- [ ] Set proper file upload limits

## Deployment

### 1. Code Deployment
- [ ] Deploy code to production server
- [ ] Install dependencies: `bundle install --deployment`
- [ ] Run database migrations: `rails db:migrate RAILS_ENV=production`
- [ ] Precompile assets: `rails assets:precompile RAILS_ENV=production`

### 2. Service Management
- [ ] Restart Rails application server
- [ ] Restart Sidekiq workers
- [ ] Clear Rails cache if needed: `rails tmp:cache:clear RAILS_ENV=production`

## Post-Deployment

### 1. Health Checks
- [ ] Visit `/health` endpoint to verify all services are running
- [ ] Check application logs for errors
- [ ] Verify Sidekiq is processing jobs at `/sidekiq`

### 2. Functionality Tests
- [ ] Test admin login
- [ ] Create a test repository
- [ ] Trigger GitHub sync for test repository
- [ ] Verify pull request data is fetched
- [ ] Check dashboard charts are rendering

### 3. Monitoring Setup
- [ ] Set up application monitoring (e.g., New Relic, AppSignal)
- [ ] Configure error tracking (e.g., Sentry, Rollbar)
- [ ] Set up uptime monitoring for `/health` endpoint
- [ ] Configure log aggregation

## Security Checklist

- [ ] Verify `config.force_ssl = true` in production
- [ ] Check that sensitive data is not logged
- [ ] Ensure GitHub token has minimal required permissions
- [ ] Verify admin authentication is working
- [ ] Check that Sidekiq Web UI requires authentication
- [ ] Review and remove any development/test data

## Rollback Plan

1. Keep previous release directory available
2. Database rollback: `rails db:rollback STEP=n RAILS_ENV=production`
3. Revert to previous code version
4. Restart all services
5. Verify functionality with health check

## Maintenance

### Regular Tasks
- Monitor disk space for logs and database
- Review and rotate logs
- Update dependencies regularly
- Monitor GitHub API rate limits
- Review Sidekiq queue sizes and processing times

### Admin User Management
- Create admin users via Rails console:
  ```ruby
  Admin.create!(email: 'admin@example.com', password: 'secure_password')
  ```
- Or use the invitation system through the UI

## Troubleshooting

### Common Issues

1. **Assets not loading**
   - Check `rails assets:precompile` completed successfully
   - Verify nginx/apache is serving from `public/assets`
   - Check `config.assets.compile = false` in production

2. **GitHub sync not working**
   - Verify `GITHUB_ACCESS_TOKEN` is set correctly
   - Check Sidekiq is running and processing jobs
   - Review logs for rate limit errors

3. **Email not sending**
   - Verify SMTP configuration in environment variables
   - Check ActionMailer configuration in production.rb
   - Review mail server logs

4. **Database connection errors**
   - Verify `DATABASE_URL` or individual DB settings
   - Check database server is accessible
   - Verify database user permissions

## Support

For issues or questions:
1. Check application logs: `tail -f log/production.log`
2. Check Sidekiq logs
3. Review this checklist
4. Check GitHub API status: https://www.githubstatus.com/