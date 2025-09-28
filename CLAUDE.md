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
# Sync all repositories (incremental, ideal for nightly cron jobs)
rake sync:all_repositories

# Sync all repositories with full refresh
rake sync:all_repositories FETCH_ALL=true

# Sync individual repository (incremental)
rake sync:repository[owner/repo]

# Sync individual repository with full refresh
rake sync:repository[owner/repo] FETCH_ALL=true

# Check sync status for a repository
rake sync:status[owner/repo]

# List all repositories and their sync status
rake sync:list

# Legacy commands (still available)
rake github:fetch_pull_requests REPO=owner/repo
rake weeks:generate
rake weeks:update_stats
```

### Environment Setup
- Set GitHub Personal Access Token: `export GITHUB_ACCESS_TOKEN=your_token_here`
- Database: PostgreSQL
- Ruby version: 3.4.4
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

## Useful AI Assistant Patterns

### For This Project
These Claude Code features are particularly useful for prmetrics development:

#### 1. **Performance Analysis**
```
"Search for N+1 queries in all controllers and views"
"Analyze database queries in the dashboard for optimization opportunities"
```

#### 2. **Security Auditing**
```
"Check for SQL injection vulnerabilities or unsafe params usage"
"Search for hardcoded credentials or API keys"
```

#### 3. **Code Consistency**
```
"Find all service objects and verify they follow the same pattern"
"Check that all controllers properly handle authentication"
```

#### 4. **Test Coverage**
```
"Identify controller actions without system tests"
"Generate edge case tests for WeekStatsService calculations"
```

#### 5. **Deployment Preparation**
```
"Search for development-specific code that needs configuration"
"Find all environment variables used in the codebase"
```

#### 6. **Documentation Generation**
```
"Generate API documentation for all public service methods"
"Create setup instructions based on the codebase structure"
```

#### 7. **Refactoring Opportunities**
```
"Identify duplicate code across models"
"Find complex methods that could be extracted into services"
```

#### 8. **Web Search for Best Practices**
```
"Search for Rails 7 production deployment checklist 2025"
"Find current best practices for Sidekiq configuration"
```

### General Tips
- Use concurrent tool operations when searching multiple areas
- Ask for the Agent tool when doing open-ended searches
- Reference earlier conversation context for consistency
- Request multi-file edits for coordinated changes

## Production Deployment

### GitHub Actions for Nightly Sync (Recommended - Free!)
To enable automatic nightly syncing using GitHub Actions (saves $25/month vs Heroku Scheduler):

#### 1. GitHub Secrets Setup
1. Get Heroku API token: `heroku authorizations:create --description "GitHub Actions Sync"`
2. Go to GitHub repository → Settings → Secrets and variables → Actions
3. Add secret:
   - **Name**: `HEROKU_API_KEY`
   - **Value**: Your Heroku API token

#### 2. Workflow Configuration
The workflow is already configured in `.github/workflows/nightly-sync.yml`:
- **Schedule**: Daily at 2 AM CT (7:00 UTC)
- **Command**: `heroku run --app prmetrics-production bundle exec rake sync:all_repositories`
- **Manual trigger**: Available from GitHub Actions UI

#### 3. Manual Testing
```bash
# Trigger workflow manually
gh workflow run "nightly-sync.yml" --repo bendycode/prmetrics

# View workflow runs
open https://github.com/bendycode/prmetrics/actions
```

#### 4. Monitoring
- **View logs**: GitHub Actions → "Nightly Repository Sync" workflow
- **Check failures**: GitHub will email you on workflow failures
- **Manual runs**: Use "Run workflow" button in GitHub UI

### Heroku Scheduler Setup (Alternative - $25/month)
If you prefer Heroku Scheduler instead of GitHub Actions:

#### 1. Add Heroku Scheduler Add-on
```bash
# Add the scheduler add-on ($25/month)
heroku addons:create scheduler:standard

# Open scheduler dashboard
heroku addons:open scheduler
```

#### 2. Configure Scheduled Job
In the Heroku Scheduler dashboard:
- **Task**: `bundle exec rake sync:all_repositories`
- **Dyno Size**: Standard-1X (recommended)
- **Frequency**: Daily
- **Time**: 02:00 UTC (or preferred time)
- **Time Zone**: UTC

#### 3. Environment Variables
Ensure these environment variables are set in Heroku:
```bash
# Required for GitHub API access
heroku config:set GITHUB_ACCESS_TOKEN=your_github_token_here

# Optional: Force full sync instead of incremental
heroku config:set FETCH_ALL=false
```

#### 4. Monitoring
```bash
# View scheduler logs
heroku logs --ps scheduler --tail

# Check recent runs
heroku logs --ps scheduler | grep "sync:all_repositories"

# Monitor Sidekiq jobs (if using async processing)
heroku logs --ps worker --tail
```

#### 5. Manual Testing
Test the scheduled task manually:
```bash
# Run the same command that scheduler will execute
heroku run bundle exec rake sync:all_repositories

# Check sync status for all repos
heroku run bundle exec rake sync:list
```

**Benefits of Heroku Scheduler:**
- Heroku-managed reliability and retry logic
- Integrated with Heroku logs and monitoring
- Automatic environment variable injection
- No additional dyno management required
- Built-in error reporting