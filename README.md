# prmetrics

## Overview

prmetrics is a Rails application designed to fetch and analyze pull request data from GitHub repositories. It provides insights into team performance and project progress by tracking various metrics related to the pull request workflow.

## Documentation

- [CHANGELOG.md](CHANGELOG.md) - History of changes and completed features
- [ROADMAP.md](ROADMAP.md) - Future development plans and priorities
- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture and design decisions
- [CLAUDE.md](CLAUDE.md) - Development guide for Claude Code

## Features

- Fetch pull request data from specified GitHub repositories
- Track metrics such as:
  - Open PRs
  - Draft PRs
  - PRs started
  - PRs merged
  - PRs canceled
  - Hours to first PR review
  - Hours to PR merge
- Store data locally to reduce API calls and enable offline analysis
- Incremental updates to minimize data transfer and processing time
- Multi-user access control with role-based authorization
- User invitation system for team collaboration

## Prerequisites

- Ruby 3.4.8 or later
- Rails 6.0 or later
- PostgreSQL
- GitHub Personal Access Token with repo scope

## Setup

1. Clone the repository:
   ```
   git clone https://github.com/your-username/prmetrics.git
   cd prmetrics
   ```

2. Install dependencies:
   ```
   bundle install
   ```

3. Set up the database:
   ```
   rails db:create db:migrate
   ```

4. Set your GitHub Personal Access Token:
   ```
   export GITHUB_ACCESS_TOKEN=your_token_here
   ```

5. Create an initial admin user:
   ```
   rails console
   User.create!(email: 'admin@example.com', password: 'password123', role: :admin)
   ```

## User Roles and Authorization

prmetrics implements role-based access control with two user roles:

### Admin Role
- **Full access** to all application features
- Can manage repositories (add, edit, delete)
- Can invite new users with either role
- Can view all data and metrics
- Default development login: `admin@example.com` / `password123`

### Regular User Role
- **Read-only access** to repository data and metrics
- Cannot manage repositories or invite users
- Can view dashboards and reports
- Suitable for team members who need visibility but not management access

### Authorization Model
The application uses [Pundit](https://github.com/varvet/pundit) for authorization:
- `RepositoryPolicy` - Controls repository management access
- `UserPolicy` - Controls user management and invitation features
- All controller actions are properly authorized
- UI elements are conditionally shown based on user permissions

### User Management
- Admins can invite new users via the `/users/invitations/new` page
- Invited users receive email invitations to set up their accounts
- Role assignment happens during the invitation process
- Users authenticate via email/password through Devise

## Usage

### Unified Sync (Recommended)

The unified sync command combines PR fetching, week generation, and statistics updates into a single command with real-time progress:

```
# Both syntaxes work:
rake sync:repository[owner/repo]
rake sync:repository owner/repo
```

For a full sync (all PRs, not just recent updates):

```
FETCH_ALL=true rake sync:repository[owner/repo]
FETCH_ALL=true rake sync:repository owner/repo
```

Additional sync commands:

```
# Check sync status for a repository (both syntaxes work)
rake sync:status[owner/repo]
rake sync:status owner/repo

# List all repositories and their sync status
rake sync:list

# Run sync in background (requires Sidekiq, both syntaxes work)
rake sync:repository_async[owner/repo]
rake sync:repository_async owner/repo
```

### Legacy Commands

Individual commands are still available but the unified sync is recommended:

```
# Fetch pull requests only
rake github:fetch_pull_requests REPO=owner/repo

# Generate week records
rake weeks:generate

# Update statistics
rake weeks:update_stats
```

## Data Analysis

(This section can be expanded as you develop more analysis features)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License.
