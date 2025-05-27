# PR Analysis Tool - Development Roadmap

This document outlines future development plans for the PR Analysis Tool. For completed work, see [CHANGELOG.md](CHANGELOG.md). For architecture decisions and technical debt, see [ARCHITECTURE.md](ARCHITECTURE.md).

## Priority Roadmap

### Phase 1: Code Quality & Stability (Next 2-4 weeks)

1. **Add Code Coverage with Ratcheting**
   - SimpleCov integration with coverage reports
   - Ratcheting test to prevent coverage regression
   - Baseline file tracking coverage improvements

2. **Integrate StandardRB**
   - Add StandardRB gem for consistent code style
   - Configure as default rake task
   - Run initial code standardization

3. **Fix Email Delivery for Admin Invites**
   - Debug production email configuration
   - Add email delivery monitoring
   - Test ActionMailer in production

### Phase 2: Architecture Improvements (4-8 weeks)

1. **Consolidate User Models**
   - Merge User and GithubUser models
   - Migrate existing data
   - Simplify relationships

2. **Refactor GithubService**
   - Extract GithubApiClient
   - Create RateLimiter service
   - Build PullRequestImporter

3. **Implement Query Objects**
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

### Infrastructure
- Multi-tenant support
- Horizontal scaling preparation
- Data archival policies
- Performance monitoring integration

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
- Fix missing u-node data for /dashboard
  - Investigate why u-node shows zeros in charts
  - Ensure week statistics are properly calculated for all repositories
  - Debug Repository Performance Comparison visibility
- Incremental statistics updates
- Automatic cleanup of cancelled jobs
- Sidekiq job monitoring improvements
- Unified sync command with real-time week generation
  - Single rake task: `github:sync REPO=owner/repo`
  - Creates week records during PR processing
  - Updates statistics incrementally
  - Shows progress with live graph updates

### Medium Priority
- View partial extraction
- Service object standardization
- Timestamp naming consistency
- Rename project from pr-analyzer to prmetrics
  - Update GitHub repository name
  - Update all references in codebase
  - Update Heroku app name if desired
  - Update any documentation/URLs

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