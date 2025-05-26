# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Development Commands

### Running the Application
```bash
# Start Rails server
rails server
# or
rails s

# Start Sidekiq (in separate terminal)
bundle exec sidekiq

# Or run both with foreman
foreman start -f Procfile.dev

# Run Rails console
rails console
# or
rails c
```

### Database Commands
```bash
# Create and migrate database
rails db:create db:migrate

# Run migrations
rails db:migrate

# Rollback migrations
rails db:rollback

# Reset database (drop, create, migrate, seed)
rails db:reset
```

### Testing
```bash
# Run all tests
bundle exec rspec
# or
rake

# Run specific test file
bundle exec rspec spec/models/pull_request_spec.rb

# Run specific test by line number
bundle exec rspec spec/models/pull_request_spec.rb:42

# Run tests with specific pattern
bundle exec rspec spec/models/
```

**Note**: Ruby 3.3.5 may show harmless DidYouMean deprecation warnings from upstream gems. 
These are safe to ignore and will be resolved when gems update their DidYouMean API usage.

### GitHub Data Fetching
```bash
# Fetch pull requests for a repository (incremental)
rake github:fetch_pull_requests REPO=owner/repo

# Fetch all pull requests (full refresh)
rake github:fetch_pull_requests REPO=owner/repo FETCH_ALL=true

# Generate week records for all repositories
rake weeks:generate

# Update week statistics
rake weeks:update_stats
```

### Environment Setup
- Set GitHub Personal Access Token: `export GITHUB_ACCESS_TOKEN=your_token_here`
- Database: PostgreSQL
- Ruby version: 3.0.6
- Rails version: ~> 7.1.4
- Redis: Required for Sidekiq background jobs
- Development admin login: admin@example.com / password123

## Architecture Overview

### Core Models and Relationships
- **Repository**: Parent entity containing pull requests
- **PullRequest**: Central model tracking PR lifecycle with GitHub timestamps
- **Review**: Tracks PR reviews with submission times
- **Week**: Aggregates statistics by week for each repository
- **User**: Generic user model for reviewers
- **GithubUser**: GitHub-specific user data for PR authors
- **PullRequestUser**: Join table linking users to PRs with specific roles

### Key Services
- **GithubService**: Handles GitHub API integration with Octokit, implements rate limiting and retry logic
- **WeekStatsService**: Calculates weekly statistics and metrics
- **SyncRepositoryJob**: Background job for asynchronous GitHub data fetching

### Important Patterns
- **WeekdayHours concern**: Custom module that calculates business hours excluding weekends
- **Incremental fetching**: Uses `last_fetched_at` on repositories to minimize API calls
- **Week associations**: PRs are associated with different weeks based on lifecycle events (started, merged, cancelled)

### UI Framework
- Uses SB Admin 2 Bootstrap theme
- jQuery and Bootstrap for frontend interactions
- Stimulus.js for JavaScript controllers

### Testing Approach
- RSpec for all tests
- FactoryBot for test data generation
- Faker for realistic test data
- Test files mirror app structure in spec/ directory

## Code Style Preferences

### Test Output
- Keep test output clean and succinct - passing tests should only show dots
- Remove debug output, puts statements, and console logging from production code
- Reserve verbose output only for test failures
- Use proper logging levels (Rails.logger) instead of puts when logging is necessary