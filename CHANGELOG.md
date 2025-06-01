# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added
- **Unified Sync Command** - Real-time week generation with progress tracking
  - New `rake sync:repository[owner/repo]` command combines PR fetch, week generation, and stats updates
  - UnifiedSyncService orchestrates the entire sync process
  - Real-time progress output showing PR processing and week creation
  - Background job support with `rake sync:repository_async[owner/repo]`
  - Additional utility commands: `sync:status[owner/repo]` and `sync:list`
  - GithubService enhanced with processor callbacks for real-time updates
  - Progress tracking stored in repository model (sync_progress field)
  - Creates week records during PR processing with incremental statistics updates

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