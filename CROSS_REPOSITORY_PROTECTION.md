# Cross-Repository Week Association Protection

## Overview
This document describes the protection mechanisms implemented to prevent pull requests from being associated with weeks from different repositories.

## Problem
Previously, pull requests could be incorrectly associated with weeks from other repositories due to:
- `Week.find_by_date` not being scoped to a specific repository
- No validation preventing cross-repository week assignments
- Week lookups finding the first matching week regardless of repository

## Solution

### 1. Model Validation
Added validation to the `PullRequest` model that ensures all week associations belong to the same repository:

```ruby
validate :weeks_belong_to_same_repository

def weeks_belong_to_same_repository
  week_associations = {
    ready_for_review_week: ready_for_review_week,
    first_review_week: first_review_week,
    merged_week: merged_week,
    closed_week: closed_week
  }
  
  week_associations.each do |association_name, week|
    if week && week.repository_id != repository_id
      errors.add(association_name, "must belong to the same repository as the pull request")
    end
  end
end
```

### 2. Repository-Scoped Week Lookups
Updated all week assignment methods to use repository-scoped queries:

**In PullRequest model:**
```ruby
def update_week_associations
  # Use repository-scoped week lookups to prevent cross-repository associations
  self.ready_for_review_week = repository.weeks.find_by_date(ready_for_review_at)
  
  first_valid_review = valid_first_review
  
  self.first_review_week = repository.weeks.find_by_date(first_valid_review&.submitted_at)
  self.merged_week = repository.weeks.find_by_date(gh_merged_at)
  self.closed_week = repository.weeks.find_by_date(gh_closed_at)
  save
end
```

**In Review model:**
```ruby
def update_pull_request_first_review_week
  return unless pull_request&.ready_for_review_at
  
  first_review = pull_request.valid_first_review
  # Use repository-scoped week lookup to prevent cross-repository associations
  new_week = first_review ? pull_request.repository.weeks.find_by_date(first_review.submitted_at) : nil
  
  if pull_request.first_review_week != new_week
    pull_request.update_column(:first_review_week_id, new_week&.id)
  end
end
```

### 3. New Helper Method
Added `Week.for_repository_and_week_number` to ensure repository-scoped week operations:

```ruby
def self.for_repository_and_week_number(repository, week_number)
  return nil unless repository && week_number
  
  repository.weeks.find_or_create_by(week_number: week_number) do |week|
    # Set begin and end dates based on week number
    year = week_number / 100
    week_of_year = week_number % 100
    
    # Calculate the start of the week (Monday)
    jan_first = Date.new(year, 1, 1)
    days_to_first_monday = (8 - jan_first.wday) % 7
    first_monday = jan_first + days_to_first_monday
    
    week.begin_date = first_monday + ((week_of_year - 1) * 7).days
    week.end_date = week.begin_date + 6.days
  end
end
```

## Testing
Comprehensive tests have been added to ensure the protection works correctly:

1. **Validation tests**: Verify that cross-repository assignments are rejected
2. **Assignment tests**: Ensure automatic week assignments use the correct repository
3. **Edge case tests**: Handle scenarios where weeks exist in one repository but not another

## Impact
- Prevents future cross-repository week associations
- Ensures data integrity for week-based reporting
- Makes the codebase more robust against data inconsistencies

## Migration
A one-time data fix was performed to correct existing cross-repository associations using the `fix_cross_repository_associations.rb` script.