# prmetrics - Development Roadmap

This document outlines future development plans for prmetrics. For completed work, see [CHANGELOG.md](CHANGELOG.md). For architecture decisions and technical debt, see [ARCHITECTURE.md](ARCHITECTURE.md).

## Priority Roadmap

### Phase 0: Critical Fixes (IMMEDIATE)

**⚠️ Issues discovered in production deployment - highest priority**

1. **Fix UI Sync State Bug** 🐛
   - Repository sync buttons remain disabled after sync completion/failure
   - Users cannot re-sync without page refresh
   - Clear sync status flags when background jobs finish
   - Prevent UI from showing "in progress" when no Sidekiq jobs are running
   - Timeline: 2-3 days

2. **Upgrade Puma to 7.0.3+** 🔧
   - Current: 6.6.0
   - Required: 7.0.3+ for Heroku Router 2.0 compatibility
   - Heroku official recommendation
   - Action: `bundle update puma && bundle exec rspec && git commit`
   - Timeline: 1 day (test thoroughly)

### Phase 1: Code Quality & Stability (Next 2-4 weeks)

1. ✅ **Integrate Linting (RuboCop)** (In Progress)
   - ✅ Added RuboCop with Ruby Style Guide defaults
   - ✅ Configured as default rake task (runs before specs)
   - ✅ Generated .rubocop_todo.yml for gradual adoption
   - ✅ Added to CI/CD pipeline (GitHub Actions)
   - 🔄 Incremental cleanup of existing violations (ongoing)

2. **Add Rails Best Practices**
   - Integrate rails_best_practices gem
   - Configure custom rules for the project
   - Add to CI/CD pipeline
   - Fix identified code smells and anti-patterns

3. **Test Suite Optimization**
   - ⏳ Enable pending specs (10 currently skipped with xit/xcontext)
     - Review and fix skipped search specs in spec/features/search_spec.rb
     - Fix webhook specs in spec/controllers/webhooks_controller_spec.rb
     - Enable Sidekiq dashboard and mentor invitation specs
   - ⏱️ Identify and optimize slowest 3 specs
     - Profile test suite to find performance bottlenecks
     - Target specs taking >5 seconds individually
     - Optimize database setup, fixtures, or test logic
   - 🚀 Improve overall rake execution time
     - Current: ~4 minutes total (RuboCop + RSpec + Teaspoon)
     - Target: <3 minutes for faster development feedback
     - Consider parallel test execution, selective test running, or test optimizations

### Phase 2: Architecture Improvements (4-8 weeks)

1. **Refactor GithubService**
   - Extract GithubApiClient
   - Create RateLimiter service
   - Build PullRequestImporter

2. **Standardize Database Statistics Caching**
   - ✅ **Add cached columns for PR aging metrics** (Completed)
     - Added `num_prs_late` column to cache PRs approved 8-27 days ago
     - Added `num_prs_stale` column to cache PRs approved 28+ days ago
     - Replaced generic "approved but unmerged" with actionable late/stale categories
     - All cached columns use historical `end_date` for consistency

   - **Continue caching pattern for remaining metrics**
     - Audit other dynamic calculations that should be cached for performance
     - Ensure `calculate_open_prs` populates and is used consistently
     - Verify all Week model cached columns are populated during sync

   - **Migrate dashboard from dynamic to cached calculations**
     - Update dashboard controller to use cached values exclusively
     - Remove complex `includes()` optimizations (no longer needed)
     - Simplify view templates to trust cached data

   - **Establish caching-first pattern for future metrics**
     - Document that all rake tasks must end with cache refresh
     - Create guidelines: new metrics should be cached unless real-time required
     - Rationale: Zero-cost caching since data only changes during controlled sync jobs

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

4. **Median Review Metrics Enhancement**
   - **Add median calculations to Week model**
     - Calculate median hours to first review (complement to existing average)
     - Calculate median hours to merge (complement to existing average)
     - Cache median values in database following established caching pattern

   - **Enhance week show page with median data**
     - Display both average and median review metrics
     - Allow user to toggle between showing average-only, median-only, or both simultaneously
     - Clear labeling to distinguish between average and median values

   - **Upgrade dashboard "Review Performance" chart**
     - Add median datasets to complement existing average lines
     - Implement user toggle controls for avg/median/both display modes
     - Maintain visual consistency with established chart styling patterns
     - Consider dual-axis if both metrics are shown simultaneously

   - **UI/UX considerations**
     - Decide on default view (average-only for consistency vs both for completeness)
     - Design clear toggle interface that doesn't clutter existing layouts
     - Add tooltips explaining difference between average vs median metrics
     - Ensure responsive design works with additional chart complexity

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

## AI & Machine Learning Features

These features leverage AI/ML to provide intelligent insights and predictions based on PR metrics data.

### AI-Powered Insights & Analysis

1. **AI-Powered PR Insights Dashboard Widget**
   - Natural language insights generation using Claude/OpenAI API
   - Automated analysis of recent PR patterns and anomalies
   - Real-time insights like "Review times increased 40% this week - 3 PRs sat unreviewed for 2+ days"
   - Contextual recommendations based on team behavior patterns
   - Optional regeneration with different focus areas (late PRs, review patterns, specific team members)
   - **Implementation**: 3-4 hours for MVP
   - **Demo potential**: High - generates readable, actionable insights
   - **Business value**: Helps teams spot problems without manual chart analysis

2. **Natural Language Metrics Query Interface**
   - Chat-style interface for asking questions about metrics
   - Examples: "Which PRs took longest to review last month?", "Show me John's review performance"
   - AI-powered query understanding and data retrieval
   - Natural language responses with supporting data and charts
   - Semantic search capabilities for domain-specific questions
   - Function calling integration with Claude API
   - **Implementation**: 4-5 hours for MVP
   - **Demo potential**: Very high - interactive, conversational UI
   - **Business value**: Democratizes data access for non-technical users

3. **Predictive PR Merge Time Estimator**
   - ML model predicting merge time based on historical patterns
   - Factors: PR size, author history, time of week, review count, file types
   - Display predictions on PR cards: "This PR will likely merge in 2-4 days"
   - Confidence intervals and explanation of prediction factors
   - Model training on repository-specific historical data
   - Options: Simple regression or more sophisticated ML models
   - **Implementation**: 4-6 hours for MVP
   - **Demo potential**: High - visual predictions with explanations
   - **Business value**: Sets realistic expectations, helps prioritization

### Future AI Enhancements
- Automated PR complexity scoring using code analysis
- Intelligent reviewer assignment based on expertise and availability
- Anomaly detection for unusual review patterns or bottlenecks
- Sentiment analysis on PR comments and reviews
- Custom insight generation based on user-defined business rules

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
- **User Role Management**
  - Add ability to edit user roles after invitation/registration
  - Implement user edit functionality with role switching
  - Add proper authorization for role changes (admin-only)
  - Include role change audit logging for security
- Breadcrumb navigation
- Global search functionality
- Advanced filtering and sorting
- Mobile-responsive design
- Progressive Web App features
- Complete brand identity implementation
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
- **Ninety.io Integration**
  - Automatically record ninety.io scoreboard updates weekly via API
  - Sync scoreboard metrics to prmetrics for unified analytics
  - Similar pattern to existing GitHub sync functionality
  - Scheduled weekly via Sidekiq job or GitHub Actions
  - Requires ninety.io API authentication and data model design

## Technical Improvements

### High Priority
- ✅ Upgrade Ruby version (Completed - Now in Phase 0)
  - Upgraded from Ruby 3.3.5 to Ruby 3.4.4
  - Next: Upgrade to 3.4.7 (see Phase 0)
- **Review and streamline deployment methods**
  - **Issue**: Duplication between Procfile release phase and bin/deploy script
  - **Goal**: Single source of truth for deployment logic
  - **Actions**:
    - Document when to use `git push heroku main` (auto) vs `bin/deploy` (manual)
    - Consolidate migration running logic to one location
    - Create deployment runbook with step-by-step procedures
    - Add deployment checklist to CLAUDE.md
  - **Timeline**: 1 week
- **Simplify code coverage threshold management**
  - **Issue**: Coverage threshold duplicated in `.coverage_baseline` and `spec/rails_helper.rb`
  - **Goal**: Single source of truth for coverage ratcheting
  - **Actions**:
    - Update `spec/rails_helper.rb` to read threshold from `.coverage_baseline`
    - Add tests to verify threshold synchronization
    - Document pattern in COVERAGE.md
  - **Timeline**: 2-3 hours
- **Rename user associations to contributor** (Semantic clarity)
  - **Issue**: `PullRequestUser.user` confusingly points to Contributor model
  - **Goal**: Code that reads naturally and matches domain model
  - **Actions**:
    - Rename `PullRequestUser` model to `PullRequestContributor`
    - Update association from `belongs_to :user` to `belongs_to :contributor`
    - Update all references in controllers, views, and tests
    - Run full test suite to verify no regressions
  - **Timeline**: 3-4 hours
  - **Note**: User model consolidation already complete (see CHANGELOG)

- **Suppress autoprefixer warnings in test output**
  - **Issue**: color-adjust deprecation warnings clutter test output
  - **Goal**: Clean test output to catch new warnings
  - **Actions**:
    - Option 1: Update autoprefixer configuration to suppress specific warnings
    - Option 2: Update SB Admin 2 theme CSS to use new properties
    - Option 3: Patch affected CSS files directly
  - **Timeline**: 1-2 hours

- **Incremental statistics updates** (Performance optimization)
  - **Issue**: Week stats recalculated fully on each sync (slow for large repos)
  - **Goal**: Update only changed weeks to improve sync performance
  - **Actions**:
    - Modify WeekStatsService to accept week range parameter
    - Update sync jobs to only recalculate affected weeks
    - Add tests for incremental vs full recalculation
    - Measure performance improvement on large repositories
  - **Timeline**: 1 week

- **Automatic cleanup of cancelled jobs**
  - **Issue**: Cancelled Sidekiq jobs leave repositories in "in_progress" state
  - **Goal**: Auto-detect and clean up stale sync states
  - **Actions**:
    - Add periodic job to check for stale sync_status
    - Reset repositories stuck "in_progress" for >30 minutes with no active job
    - Add monitoring/alerting for cleanup events
  - **Timeline**: 3-4 hours

- **Sidekiq job monitoring improvements**
  - **Issue**: Limited visibility into job failures and performance
  - **Goal**: Better observability of background job health
  - **Actions**:
    - Add custom Sidekiq middleware for job timing
    - Implement job failure notifications (email or Slack)
    - Create dashboard for job metrics
    - Add retry exhausted handling with alerts
  - **Timeline**: 1-2 days

### Medium Priority
- **Improve rate limit messaging**
  - **Issue**: Rate limit wait times shown as raw seconds (e.g., "2387 seconds")
  - **Goal**: User-friendly messaging during GitHub API rate limiting
  - **Actions**:
    - Convert seconds to "X hours Y minutes" format
    - Add explanation of what's happening during rate limit wait
    - Show progress bar or countdown timer
    - Display when API quota will reset
  - **Timeline**: 2-3 hours

- **View partial extraction**
  - **Issue**: Large view files with duplicated code
  - **Goal**: DRY principles and maintainable views
  - **Actions**:
    - Identify repeated view patterns (cards, tables, charts)
    - Extract to partials in `app/views/shared/`
    - Use view components for complex UI elements
    - Document partial usage patterns
  - **Timeline**: 1 week

- **Service object standardization**
  - **Issue**: Inconsistent service object patterns across codebase
  - **Goal**: Consistent, predictable service architecture
  - **Actions**:
    - Document standard service object pattern (initialize, call, result)
    - Create BaseService class with common patterns
    - Refactor existing services to match standard
    - Add service object guidelines to ARCHITECTURE.md
  - **Timeline**: 1 week

- **Timestamp naming consistency**
  - **Issue**: Mix of `gh_created_at` (GitHub) and `created_at` (Rails) naming
  - **Goal**: Clear, consistent timestamp naming convention
  - **Actions**:
    - Document naming convention: `gh_*` for GitHub, `*_at` for local
    - Audit all timestamp columns for naming clarity
    - Create migration to rename confusing timestamps
    - Update corresponding model code and tests
  - **Timeline**: 3-4 hours

### Low Priority
- Dead code removal
- Test suite optimization
- Documentation improvements

## Success Metrics

### Current Status & Targets

**Code Quality**
- Code coverage: 84.48% → Target: 90% (incremental ratcheting)
  - Current baseline: 84.48% (established 2025-06-03)
  - Next milestone: 86% by end of Phase 1
  - Final target: 90% by end of Phase 2

**Performance**
- Page load times: Baseline TBD → Target: < 200ms for all pages
  - Establish baseline with performance monitoring (Phase 4)
  - Optimize slowest pages first
- N+1 queries: Currently tracked → Target: Zero in production
  - Bullet gem alerts in development
  - Query optimization tests prevent regressions

**Reliability**
- Uptime: Current ~99%+ → Target: 99.9% for critical paths
  - Critical paths: Dashboard, repository sync, PR data display
  - Implement health checks and monitoring (Phase 4)
- Data sync freshness: Nightly (automated) → Target: < 1 hour for on-demand
  - Nightly automated sync: ✅ Implemented
  - Manual sync: Available via UI
  - Incremental sync optimization: Phase 2

**User Experience**
- Sync feedback: Manual refresh → Target: Real-time progress updates
  - Implement ActionCable live updates (Phase 4)
  - Progress bars for long-running operations
- Error messages: Generic → Target: Specific, actionable messages
  - User-friendly rate limit messages (Medium Priority)
  - Helpful error context throughout app