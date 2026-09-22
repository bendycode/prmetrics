# Architecture

This document describes the architecture, design decisions, and technical patterns used in prmetrics.

## Overview

prmetrics is a Rails application that fetches and analyzes pull request data from GitHub repositories to provide metrics and insights about development velocity and code review performance.

## Core Architecture

### Models and Relationships

```
Repository (1) ─── (N) PullRequest (1) ─── (N) Review
     │                      │
     │                      ├─── (N) PullRequestUser ─── (1) Contributor
     │                      │
     │                      ├─── (1) Contributor (author)
     │                      │
     │                      └─── (1) Contributor (merged_by)
     │
     └─── (N) Week
```

- **Repository**: Parent entity containing GitHub repository information
- **PullRequest**: Central model tracking PR lifecycle with GitHub timestamps, its base and head branches, and who merged it
- **Review**: Individual PR reviews with submission times and states
- **Week**: Time-based aggregation of PR statistics
- **Contributor**: Unified model for all PR participants (authors, reviewers and mergers) with GitHub data, flagged as a bot when GitHub reports the account as one
- **PullRequestUser**: Join table linking contributors to PRs; the sync writes only the author row

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

#### Promotions vs Development Work
A promotion pull request deploys rather than develops: it merges into one of the repository's deploy branches, such as `main` into `production`. A deploy branch is one the default branch's own merged pull requests go into and that never merges back into the default branch, which is what tells it from a long-lived feature branch someone merged the default branch into to catch it up. Each sync records the repository's default branch and reclassifies its pull requests.

Promotions stay stored and readable on the pull request pages; they count toward no metric. `PullRequest.development`, `Repository#development_pull_requests` and the `Week` associations apply the exclusion, so every figure, average and week list reads through it.

#### UnifiedSyncService
Runs one repository's sync:
- Fetches pull requests and reviews through GithubService, incrementally or in full
- Records the repository's default branch and reclassifies its promotions
- Reads each pull request's events once, for when it left draft and who merged it
- Creates the weeks each pull request touches and refreshes their statistics
- Records sync status, progress, and errors on the repository

### Background Processing

Uses Sidekiq with Redis for asynchronous operations:
- **UnifiedSyncJob**: Runs UnifiedSyncService for the app's Sync buttons and `rake sync:repository_async`; the nightly `rake sync:all_repositories` runs the service directly
- **UpdateRepositoryStatsJob** (`low` queue): Rebuilds every repository's weeks and statistics after a sync from the app
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

- **Framework**: Ruby on Rails, at the version in the Gemfile
- **Ruby Version**: see `.ruby-version`
- **Database**: PostgreSQL
- **Background Jobs**: Sidekiq with Redis
- **Testing**: RSpec with FactoryBot
- **UI Framework**: SB Admin 2 (Bootstrap theme)
- **JavaScript**: Stimulus.js
- **Authentication**: Devise with Devise Invitable

## Design Decisions

### Unified Contributor Model
The application uses distinct models for different types of users:
- **Admin**: For application authentication (Devise)
- **Contributor**: For all PR participants (authors, reviewers, assignees)

**Rationale**: Keeps authentication separate from domain logic, while unifying GitHub user data to eliminate duplication and simplify relationships.

### One Job per Sync
A sync runs as a single background job that pages through GitHub's pull requests. A worker restart mid-sync starts it over from the first page, which the current repositories (a few thousand pull requests each) tolerate.

**Rationale**: One implementation serves the nightly task and the Sync buttons.

### Weekday-Only Time Calculations
Review and merge times exclude weekends by default.

**Rationale**: Provides more accurate business metrics for team performance.

### Cascading Deletes
Repository deletion cascades to all associated data with smart contributor cleanup.

**Rationale**: Maintains data integrity while preserving contributor history. Only orphaned PR authors are deleted; reviewers are preserved for future activity.

## Technical Debt

### High Priority
1. **GithubService Refactoring**: Extract responsibilities into focused services
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