# PR Analysis Tool

## Overview

PR Analysis Tool is a Rails application designed to fetch and analyze pull request data from GitHub repositories. It provides insights into team performance and project progress by tracking various metrics related to the pull request workflow.

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

## Prerequisites

- Ruby 3.0.6 or later
- Rails 6.0 or later
- PostgreSQL
- GitHub Personal Access Token with repo scope

## Setup

1. Clone the repository:
   ```
   git clone https://github.com/your-username/pr-analysis-tool.git
   cd pr-analysis-tool
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

## Usage

To fetch pull request data for a repository:

```
rake github:fetch_pull_requests REPO=owner/repo
```

To fetch all pull requests (including those that haven't been updated recently):

```
rake github:fetch_pull_requests REPO=owner/repo FETCH_ALL=true
```

## Data Analysis

(This section can be expanded as you develop more analysis features)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License.
