# prmetrics - Development Roadmap

This document outlines future development plans for prmetrics. For completed work, see [CHANGELOG.md](CHANGELOG.md). For architecture decisions and technical debt, see [ARCHITECTURE.md](ARCHITECTURE.md).

## Priority Roadmap

### Phase 1: Code Quality & Stability (Next 2-4 weeks)

1. **Enhance GitHub Data Sync Reliability**
   - Add GitHub issue events sync to capture ready_for_review timing changes
   - Implement more robust incremental sync logic
   - Add validation for sync completeness

2. **Integrate StandardRB**
   - Add StandardRB gem for consistent code style
   - Configure as default rake task
   - Run initial code standardization

3. **Add Rails Best Practices**
   - Integrate rails_best_practices gem
   - Configure custom rules for the project
   - Add to CI/CD pipeline
   - Fix identified code smells and anti-patterns

### Phase 2: Architecture Improvements (4-8 weeks)

1. **Refactor GithubService**
   - Extract GithubApiClient
   - Create RateLimiter service
   - Build PullRequestImporter

2. **Implement Query Objects**
   - WeeklyMetricsQuery
   - PullRequestStatsQuery
   - ReviewerPerformanceQuery

### Phase 3: Feature Enhancements (2-3 months)

1. **User Avatars**
   - Gravatar integration
   - Custom avatar uploads
   - Display throughout application

2. **Enhanced GitHub Integration**
   - Webhook support for real-time updates
   - PR labels and filtering
   - Comment metrics tracking

3. **Advanced Analytics**
   - Custom date range filtering
   - Export to CSV/PDF
   - Scheduled email reports

### Phase 4: Performance & Scale (3-6 months)

1. **Caching Implementation**
   - Russian Doll caching for statistics
   - Redis caching for expensive queries
   - API response caching

2. **Real-time Features**
   - ActionCable for live updates
   - Progress indicators
   - Activity feeds

3. **API Development**
   - RESTful API endpoints
   - API authentication
   - Rate limiting

## Feature Backlog

### Analytics & Reporting
- Multi-repository dashboard visualization
  - Repository filter dropdown (Option 1 - Quick Fix)
  - Stacked/grouped charts per repository (Option 2)
  - Tabbed repository sections (Option 3)
  - Side-by-side repository comparisons (Option 4)
- Exclude incomplete current week from dashboard
  - Hide current week if not finished and no data present
  - Prevents misleading partial week statistics
- Team performance comparisons
- PR complexity metrics (size, files, comments)
- Trend analysis and predictions
- Custom metric definitions

### User Experience
- Breadcrumb navigation
- Global search functionality
- Advanced filtering and sorting
- Mobile-responsive design
- Progressive Web App features
- Complete brand identity implementation
  - Add favicon using logo (multiple sizes for different devices) ✓
  - Improve favicon design for better visibility at small sizes
    - Consider simplified icon version for 16x16 and 32x32 sizes
    - Optimize contrast and visual weight for favicon contexts
    - Test across different browser themes and operating systems
  - Include logo in email templates (admin invitations, notifications)
  - Add logo to error pages (404, 500, 422)
  - Create Open Graph meta tags with logo for social sharing
  - Add logo to PDF exports when implemented
  - Include logo in Sidekiq Web UI header

### Infrastructure
- Multi-tenant support
- Horizontal scaling preparation
- Data archival policies
- Performance monitoring integration
- Configurable timezone per repository
  - Support teams in different time zones
  - Repository-specific business week calculations
  - Timezone-aware metric displays and week boundaries

### Security
- GitHub token encryption
- OAuth flow support
- Token rotation reminders
- Audit logging

### Integrations
- Slack notifications
- JIRA integration
- CI/CD pipeline metrics
- Third-party webhooks

## Technical Improvements

### High Priority
- ✅ Upgrade Ruby version (Completed)
  - Upgraded from Ruby 3.3.5 to Ruby 3.4.4
  - Updated Gemfile, .ruby-version, Dockerfile
  - Tested compatibility with all gems and Rails 7.1.4
  - All tests passing (312 examples, 0 failures)
- **Fix UI sync state bug**
  - Repository sync buttons remain disabled after sync completion/failure
  - Clear sync status flags when background jobs finish
  - Prevent UI from showing "in progress" when no Sidekiq jobs are running
- **Implement automated nightly sync jobs**
  - Set up cron jobs to sync all repositories automatically
  - Ensure consistent data freshness without manual intervention
  - Configure appropriate scheduling to avoid GitHub rate limits
- Suppress autoprefixer warnings in test output
  - Remove color-adjust deprecation warnings from rake/rspec runs
  - Options: Update SB Admin 2 theme, patch CSS files, or configure autoprefixer
  - Critical for maintaining clean test output and catching new warnings
- Incremental statistics updates
- Automatic cleanup of cancelled jobs
- Sidekiq job monitoring improvements

### Medium Priority
- Improve rate limit messaging
  - Convert seconds to human-readable format (e.g., "39 minutes 47 seconds")
  - Add context about what's happening during the wait
  - Consider showing progress or estimated completion time
- View partial extraction
- Service object standardization
- Timestamp naming consistency

### Low Priority
- Dead code removal
- Test suite optimization
- Documentation improvements

## Success Metrics

- Code coverage > 90%
- Page load times < 200ms
- Zero N+1 queries
- 100% uptime for critical paths
- Sub-second PR data refresh