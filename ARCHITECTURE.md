# Architecture

This document describes the architecture, design decisions, and technical patterns used in prmetrics.

## Overview

prmetrics is a Rails application that fetches and analyzes pull request data from GitHub repositories to provide metrics and insights about development velocity and code review performance.

## Core Architecture

### Models and Relationships

```
Repository (1) ─── (N) PullRequest (1) ─── (N) Review
     │                      │
     │                      ├─── (N) PullRequestUser ─── (1) User
     │                      │
     │                      └─── (1) GithubUser (author)
     │
     └─── (N) Week
```

- **Repository**: Parent entity containing GitHub repository information
- **PullRequest**: Central model tracking PR lifecycle with GitHub timestamps
- **Review**: Individual PR reviews with submission times and states
- **Week**: Time-based aggregation of PR statistics
- **User**: Generic user model for reviewers
- **GithubUser**: GitHub-specific user data for PR authors
- **PullRequestUser**: Join table linking users to PRs with reviewer/assignee roles

### Key Services

#### GithubService
Handles all GitHub API interactions using Octokit gem:
- Implements rate limiting and retry logic
- Supports incremental fetching via `last_fetched_at`
- Handles data transformation from GitHub API to local models

#### WeekStatsService
Calculates weekly statistics for repositories:
- Aggregates PR counts by lifecycle stage
- Calculates average review and merge times
- Excludes weekends from time calculations

#### RepositorySyncService
Determines optimal sync strategy:
- Routes to batch processing for large repositories
- Manages sync status and error handling

### Background Processing

Uses Sidekiq with Redis for asynchronous operations:
- **SyncRepositoryJob**: Standard sync for smaller repositories
- **SyncRepositoryBatchJob**: Batch processing (100 PRs at a time) to avoid timeouts
- Sync status tracking: `in_progress`, `completed`, `failed`

### Key Design Patterns

#### Concerns
- **WeekdayHours**: Shared module for calculating business hours excluding weekends

#### Incremental Data Fetching
- Repositories track `last_fetched_at` timestamp
- Only fetches PRs updated after last sync
- Full refresh available via `FETCH_ALL` parameter

#### Week Associations
PRs are associated with different weeks based on lifecycle events:
- `ready_for_review_week`: When PR became ready for review
- `first_review_week`: When first review was submitted
- `merged_week`: When PR was merged
- `closed_week`: When PR was closed without merging

## Technical Stack

- **Framework**: Ruby on Rails 7.1.4
- **Ruby Version**: 3.3.5
- **Database**: PostgreSQL
- **Background Jobs**: Sidekiq with Redis
- **Testing**: RSpec with FactoryBot
- **UI Framework**: SB Admin 2 (Bootstrap theme)
- **JavaScript**: Stimulus.js
- **Authentication**: Devise with Devise Invitable

## Design Decisions

### Separate User Models
The application maintains two user models:
- **Admin**: For application authentication (Devise)
- **User/GithubUser**: For PR participants

**Rationale**: Keeps authentication separate from domain logic, allows for non-GitHub admins.

### Batch Processing for Large Repositories
Large repository syncs are automatically batched to avoid Heroku's 30-minute timeout.

**Rationale**: Prevents job failures and provides better progress tracking.

### Weekday-Only Time Calculations
Review and merge times exclude weekends by default.

**Rationale**: Provides more accurate business metrics for team performance.

### Cascading Deletes
Repository deletion cascades to all associated data except User records.

**Rationale**: Maintains data integrity while preserving reviewer history across repositories.

## Technical Debt

### High Priority
1. **User Model Consolidation**: Merge User and GithubUser models to reduce complexity
2. **GithubService Refactoring**: Extract responsibilities into focused services
   - GithubApiClient for API communication
   - RateLimiter for rate limit logic
   - PullRequestImporter for data transformation

### Medium Priority
1. **Query Object Pattern**: Extract complex queries from models into dedicated query objects
2. **Caching Implementation**: Add Russian Doll caching for expensive calculations
3. **API Versioning**: Prepare for public API with proper versioning

### Low Priority
1. **Timestamp Naming**: Inconsistent naming between `gh_created_at` and Rails timestamps
2. **Service Object Standardization**: Establish consistent patterns for service objects
3. **View Partial Extraction**: Reduce view complexity by extracting reusable partials

## Security Considerations

- All controllers require authentication via Devise
- GitHub tokens stored as environment variables
- Invite-only admin system prevents unauthorized access
- Sidekiq Web UI protected by authentication middleware

## Performance Optimizations

### Database
- 14 indexes on foreign keys and frequently queried columns
- Eager loading to prevent N+1 queries
- Query optimization specs to catch regressions

### Background Processing
- Asynchronous GitHub API calls prevent request timeouts
- Batch processing for large data sets
- Progress tracking for long-running operations

## Deployment

- **Platform**: Heroku
- **Add-ons**: 
  - Heroku Postgres
  - Heroku Data for Redis
- **Configuration**: Environment variables for sensitive data
- **Monitoring**: Application logs, Sidekiq Web UI

## Future Considerations

1. **Webhook Integration**: Replace polling with GitHub webhooks for real-time updates
2. **Horizontal Scaling**: Prepare for multiple worker dynos
3. **Data Retention**: Implement policies for archiving old PR data
4. **Multi-tenancy**: Support for multiple organizations/teams