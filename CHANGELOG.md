# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Changed
- **Puma Web Server Upgrade** (2025-10-23)
  - Upgraded from Puma 6.6.0 to Puma 7.1.0
  - Deployed to production as Heroku release v90
  - Reviewed Puma 7.0 breaking changes: no impact on application
  - No configuration changes required (no hooks used, preload_app! explicitly set)
  - Ruby 3.4.7 exceeds Puma 7's minimum requirement of Ruby 3.0+
  - All tests passing (529 examples, 0 failures)
  - Zero RuboCop offenses (144 files inspected)
  - PR #5: https://github.com/bendycode/prmetrics/pull/5
- **Ruby Version Upgrade**
  - Upgraded from Ruby 3.4.4 to Ruby 3.4.7
  - Updated all version configuration files (.ruby-version, .tool-versions, Gemfile, Dockerfile)
  - Updated GitHub Actions CI workflow to use Ruby 3.4.7
  - Includes security patches and bug fixes from Ruby 3.4.5, 3.4.6, and 3.4.7 releases
  - All tests passing with zero deprecation warnings

### Added
- **Bundler Version Update**
  - Automatically upgraded from 2.6.2 to 2.6.9 during Heroku deployment
  - Maintains compatibility with latest Heroku buildpack
  - No manual intervention required
- **RuboCop Integration in Default Rake Tasks**
  - Added RuboCop linting to the standard `rake` command
  - Default task now runs `rubocop` first, then `spec`
  - Ensures code style checks run automatically with tests
  - All CI/CD pipelines now enforce code quality standards
- **Automated Nightly Sync Jobs**
  - Implemented GitHub Actions workflow for automatic nightly repository syncing
  - Scheduled daily at 2 AM CT (7:00 UTC) via `.github/workflows/nightly-sync.yml`
  - Runs `rake sync:all_repositories` via Heroku CLI
  - Manual trigger available from GitHub Actions UI
  - Free alternative to Heroku Scheduler ($25/month savings)
  - Ensures consistent data freshness without manual intervention
- **Enhanced GitHub Data Sync Reliability**
  - Added GitHub issue events sync to capture ready_for_review timing changes
  - Implemented more robust incremental sync logic
  - Added validation for sync completeness
- **Late and Stale PR Tracking** (feature/late-and-stale-prs)
  - Replaced generic "Approved but Unmerged PRs" metric with actionable categories
  - Added `num_prs_late` column: PRs approved 8-27 days ago (warning state)
  - Added `num_prs_stale` column: PRs approved 28+ days ago (urgent state)
  - Grace period: PRs approved ≤7 days are not flagged
  - Cached columns with historical consistency using week `end_date`
  - Dynamic methods for "View PRs" functionality with temporal accuracy
  - Dashboard chart now shows Late PRs (orange) and Stale PRs (red) datasets
  - Week show page displays counts with clickable "View PRs" links
  - Comprehensive test coverage: 21 new tests, 100% coverage on new code
  - Automated backfill via data_migrate gem on deployment
  - Code coverage increased from 80.07% to 84.48% (+4.41%)

### Fixed
- **Week Association Data Integrity**
  - Fixed 64 PRs with inconsistent week associations from different repositories in production
  - Ran `rake fix:week_associations` to correct cross-repository associations
  - Added validation to PullRequest model to prevent cross-repository week assignments
  - All PRs now correctly associated with weeks from their own repositories
- **Orphaned Contributors Cleanup**
  - Cleaned up 3 orphaned contributors in production (contributors with no PR associations)
  - Ran `rake cleanup:orphaned_contributors` to remove orphaned records
  - Improved data integrity in contributors table

## [2025-06-03]

### Added
- **Code Coverage with Ratcheting System**
  - SimpleCov integration with HTML and console coverage reports
  - Ratcheting system prevents coverage regression and auto-updates baseline
  - Current coverage baseline established at 77.88% (771/990 lines)
  - CI integration with `rake coverage:ratchet` and `rake ci:all` commands
  - Coverage trend tracking and baseline management
  - Comprehensive rake tasks: status, trend, update_baseline
  - COVERAGE.md documentation with usage instructions
- **Favicon Implementation**
  - Multi-size favicon generated from prmetrics logo SVG
  - White background for visibility on dark browser themes
  - Progressive Web App support with site.webmanifest
  - Apple touch icons and Android Chrome icons (192x192, 512x512)
  - Comprehensive system tests for favicon presence and functionality
  - Updated application and admin layouts with favicon meta tags

### Fixed
- **Full Sync Validation Errors**
  - Fixed "Ready for review week must belong to the same repository" errors during Full Sync
  - Added `ensure_weeks_exist_and_update_associations` method to create missing weeks before associations
  - GithubService now skips week updates when UnifiedSyncService processor is provided
  - UnifiedSyncService handles week creation and associations after PR processing
  - Updated rake tasks and batch jobs to use new week creation method

## [Previous Releases]

### Added (Unreleased items moved to 2025-06-03)
- **Unified Sync Command** - Real-time week generation with progress tracking
  - New `rake sync:repository[owner/repo]` command combines PR fetch, week generation, and stats updates
  - UnifiedSyncService orchestrates the entire sync process
  - Real-time progress output showing PR processing and week creation
  - Background job support with `rake sync:repository_async[owner/repo]`
  - Additional utility commands: `sync:status[owner/repo]` and `sync:list`
  - GithubService enhanced with processor callbacks for real-time updates
  - Progress tracking stored in repository model (sync_progress field)
  - Creates week records during PR processing with incremental statistics updates
- **Cross-Repository Week Association Protection**
  - Added validation to PullRequest model preventing weeks from different repositories
  - Updated all week assignment methods to use repository-scoped queries
  - Added Week.for_repository_and_week_number helper method for safe operations
  - Comprehensive test coverage for cross-repository protection
  - Fixed 327 existing cross-repository associations in production data

### Changed
- **Consolidated User Models** - Merged User and GithubUser into single Contributor model
  - Merged User and GithubUser tables into contributors table with unified schema
  - Combined fields: username, name, email (from User) + github_id, avatar_url (from GithubUser)
  - Updated all associations and foreign keys to reference contributors
  - Renamed UsersController to ContributorsController with corresponding views and routes
  - Enhanced GithubService methods: find_or_create_github_user → find_or_create_from_github
  - Added Contributor.find_or_create_from_username for legacy user creation
  - Implemented smart cleanup logic for orphaned contributors (authors only, preserves reviewers)
  - Migrated 20 existing users while preserving all 2845 pull request relationships
  - Simplified associations and eliminated duplication across the codebase

### Fixed
- **Dashboard Data Issues**
  - Fixed missing u-node repository data on dashboard charts
  - Corrected week statistics calculations for all repositories
  - Repository Performance Comparison now properly displays all repository data
  - Fixed cross-repository week associations preventing proper stats aggregation

## [2025-05-31]

### Added
- prmetrics logo implementation
  - Added SVG logo to sidebar navigation
  - Added logo to admin login page
  - Improved logo visibility with white background and larger size
  - Added comprehensive branding tests
- Domain redirect middleware to handle URL transitions
  - Automatic redirects from old pr-analyzer URLs to new prmetrics URLs
  - Support for future custom domain configuration
  - Rake tasks for domain configuration verification

### Changed
- Updated GUI branding from "pr-analyzer" to "prmetrics.io"
  - Changed page titles in admin and application layouts
  - Updated sidebar brand text
  - Updated footer copyright text
  - Changed navigation bar branding
  - Updated default email sender domain to prmetrics.io
- Renamed project from pr-analyze/pr-analyzer to prmetrics
  - Updated all database names to prmetrics_* format
  - Changed cable channel prefix and ActiveJob queue prefix
  - Renamed environment variables (PR_ANALYZE_* to PRMETRICS_*)
  - Updated documentation and configuration files
  - Changed default admin email domain
  - Note: Requires database recreation in development
- Updated GitHub repository name from pr-analyze to prmetrics
- Updated Heroku app name from pr-analyzer-production to prmetrics-production
  - New URL: https://prmetrics-production.herokuapp.com
  - Old URL will redirect automatically during transition period

### Fixed
- Email delivery for admin invites
  - Confirmed working in production
  - Admin invitation emails now successfully sent with "Invitation instructions" subject line

## [2025-05-26]

### Added
- Repository delete functionality with cascading deletes
  - Cascading delete for pull requests, reviews, and weeks
  - Automatic cleanup of orphaned GitHub users
  - Delete buttons on repository index and show pages
- Clickable Total Repositories dashboard card with hover effects
- Rake task for manual sync status reset (`sync:reset_status`)
- Automatic cleanup of cancelled jobs to roadmap

### Fixed
- Repository sync status stuck in "in progress" after job cancellation

## [2025-05-24]

### Added
- Admin authentication system using Devise
  - Separate Admin model for authentication
  - Invite-only system with Devise Invitable
  - Admin management UI with listing and invitation features
  - Protection against deleting last active admin
  - Secured Sidekiq Web UI with admin authentication
  - "My Account" section for password changes
  - Comprehensive test coverage for authentication

### Security
- All controllers protected with authentication
- Email invitations with secure tokens for password setup

## [2025-05-23]

### Added
- Repository creation functionality
  - Form validation for owner/repository format
  - Auto-generation of GitHub URL from repository name
  - Automatic initial sync on repository creation
- Batch processing for large repository syncs
  - SyncRepositoryBatchJob for processing in chunks of 100
  - RepositorySyncService to determine sync strategy
  - Protection against Heroku's 30-minute timeout
- Health check endpoint at `/health`
- Development and deployment documentation

### Changed
- Modified sync to use batch processing by default
- Updated logging to use Rails.logger instead of puts

### Fixed
- Test failures related to repository name validation
- Long-running sync jobs timing out on Heroku

## [2025-05-15]

### Added
- Background job processing with Sidekiq and Redis
  - SyncRepositoryJob for asynchronous GitHub data fetching
  - Repository sync status tracking (in_progress, completed, failed)
  - Sync progress indicators in UI
  - Sidekiq Web UI at `/sidekiq`
- Performance indexes on database
  - 14 strategic indexes on foreign keys and timestamp columns
  - Query performance improvements of 35-49%
  - Query optimization tests to prevent N+1 regressions

### Fixed
- N+1 query issues in multiple controllers
  - WeeksController#show
  - PullRequestUsersController
  - UsersController
- Missing eager loading for associations

## [2025-05-10]

### Added
- Dashboard with analytics charts
  - PR velocity trends (last 12 weeks)
  - Review performance metrics
  - Repository comparison charts
  - Recent activity sections
- Navigation improvements
  - User dropdown menu in top navigation
  - Fixed broken avatar images
  - Logout functionality

### Changed
- Set dashboard as root path instead of repositories index

## [Earlier Development]

### Added
- Core models and associations
  - Repository, PullRequest, Review, Week, User, GithubUser
  - WeekdayHours concern for business hours calculations
- GitHub integration
  - GithubService for API interactions
  - Incremental fetching with last_fetched_at tracking
  - Rate limiting and retry logic
- Weekly statistics
  - Week model for aggregating PR metrics
  - WeekStatsService for calculations
  - Automatic week associations for PRs
- Basic UI with SB Admin 2 theme
  - Repository management views
  - Pull request listings
  - Review tracking
  - User statistics

### Technical Foundation
- Rails 7.1.4 application
- PostgreSQL database
- RSpec test suite with FactoryBot
- Bootstrap UI with jQuery
- Stimulus.js for JavaScript controllers