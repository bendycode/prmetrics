# prmetrics - Development Roadmap

This document outlines future development plans for prmetrics. For completed work, see [CHANGELOG.md](CHANGELOG.md). For architecture decisions and technical debt, see [ARCHITECTURE.md](ARCHITECTURE.md).

## Priority Roadmap

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
- **Review and streamline deployment methods**
  - Evaluate duplication between Procfile release phase and bin/deploy script
  - Consider consolidating migration logic to single source of truth
  - Simplify manual deployment workflow while maintaining safety checks
  - Document recommended deployment practices and when to use each method
- **Add rubocop to our default rake tasks**
  - Include rubocop linting in the standard rake task
  - Ensure code style checks run automatically with tests
  - Fix asdf environment issues preventing rubocop execution
- **Simplify code coverage threshold management**
  - Currently duplicated in both `.coverage_baseline` file and `spec/rails_helper.rb`
  - Consolidate to single source of truth (likely `.coverage_baseline`)
  - Update rails_helper.rb to read from `.coverage_baseline` file
  - Ensures consistency and eliminates manual synchronization errors
- **Rename user associations to contributor where it really meant contributor**
  - Update PullRequestUser model to use `contributor` association instead of `user`
  - Rename PullRequestUser model to ContributorPullRequest since it's joining with contributors, not users
  - Change association references from `user` to `contributor` throughout codebase where that's appropriate
  - Update corresponding controller logic and view references for clarity
  - Ensure semantic consistency: User model for authentication, Contributor for PR participation
  - **Note**: This item identified during multi-user access control implementation (Phase 1 complete)
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