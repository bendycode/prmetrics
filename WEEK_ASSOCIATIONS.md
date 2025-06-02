# Week Associations - Data Integrity Guide

This document explains how week associations work in prmetrics and how to maintain data integrity.

## Overview

Week associations link pull requests to specific weeks based on when lifecycle events occur:

- `ready_for_review_week_id` - Week when PR became ready for review
- `first_review_week_id` - Week when first review was submitted  
- `merged_week_id` - Week when PR was merged
- `closed_week_id` - Week when PR was closed

## Automatic Maintenance

### Model Callbacks ✅
The `PullRequest` model automatically updates week associations when lifecycle dates change:

```ruby
after_save :update_week_associations_if_needed
```

This ensures associations stay consistent when:
- `ready_for_review_at` changes
- `gh_merged_at` changes
- `gh_closed_at` changes  
- `gh_created_at` changes

### Service Integration ✅
All sync services call `update_week_associations`:
- `GithubService.process_pull_request`
- `SyncRepositoryBatchJob.process_single_pull_request`
- `UnifiedSyncService`

## Data Integrity Checks

### Validation Commands
```bash
# Check for inconsistencies (safe, read-only)
rake validate:week_associations

# Fix inconsistencies
rake fix:week_associations

# Quick CI check (samples data for performance)
rake ci:data_integrity
```

### Automated Checks
- **Deploy script** runs `rake ci:data_integrity` after migrations
- **CI/CD pipeline** should include data integrity checks
- **Monitoring** should alert on week association inconsistencies

## Potential Risk Scenarios

### 🔴 High Risk - Could Break Data Integrity

1. **Direct Database Updates**
   ```sql
   -- ❌ BAD: Direct SQL bypasses model callbacks
   UPDATE pull_requests SET gh_merged_at = '2025-05-15' WHERE id = 123;
   ```
   
   ```ruby
   # ✅ GOOD: Use model methods
   pr = PullRequest.find(123)
   pr.update!(gh_merged_at: Time.parse('2025-05-15'))
   ```

2. **Bulk Updates Without Callbacks**
   ```ruby
   # ❌ BAD: Bypasses callbacks
   PullRequest.where(state: 'closed').update_all(gh_closed_at: Time.current)
   ```
   
   ```ruby
   # ✅ GOOD: Update individually to trigger callbacks
   PullRequest.where(state: 'closed').find_each do |pr|
     pr.update!(gh_closed_at: Time.current)
   end
   ```

3. **Console Operations**
   ```ruby
   # ❌ BAD: Raw attribute assignment
   pr.gh_merged_at = Time.current
   pr.save(validate: false)
   ```
   
   ```ruby
   # ✅ GOOD: Use update methods
   pr.update!(gh_merged_at: Time.current)
   ```

### 🟡 Medium Risk - Monitor Carefully

1. **Data Migrations**
   - Always run `rake fix:week_associations` after data migrations
   - Include week association updates in migration code when touching lifecycle dates

2. **Factory Data in Tests**
   - Factory now automatically calls `update_week_associations` 
   - Still validate test data doesn't create inconsistent states

### 🟢 Low Risk - Should Work Correctly

1. **Normal Application Flow**
   - GitHub sync operations ✅
   - Admin updates through forms ✅
   - API updates using model methods ✅

## Troubleshooting

### Symptoms of Week Association Issues
- Statistics don't match actual PR counts
- Dashboard shows incorrect week data
- Different counts between environments

### Investigation Steps
1. **Run validation**: `rake validate:week_associations`
2. **Check recent changes**: Look for database migrations, bulk updates, or console operations
3. **Sample problematic PRs**: 
   ```ruby
   # Check specific PR associations
   pr = PullRequest.find(123)
   puts "Merged at: #{pr.gh_merged_at}"
   puts "Assigned week: #{pr.merged_week&.week_number}"
   puts "Expected week: #{Week.find_by_date(pr.gh_merged_at)&.week_number}"
   ```

### Fixing Issues
1. **Individual PR**: `pr.update_week_associations`
2. **All PRs**: `rake fix:week_associations` 
3. **Recalculate statistics**: `rake fix:week_stats`

## Best Practices

### For Developers
1. **Always use model methods** for PR updates
2. **Test with realistic data** - factories now handle week associations
3. **Run validation** after data migrations
4. **Check CI** includes data integrity checks

### For Operations
1. **Monitor deploy script** for data integrity warnings
2. **Run weekly validation** in production: `rake validate:week_associations`
3. **Include integrity checks** in monitoring/alerting
4. **Document any manual database operations**

### For Data Migrations
```ruby
# Template for safe data migration
class UpdatePullRequestData < ActiveRecord::Migration[7.1]
  def up
    # 1. Make your data changes
    PullRequest.where(condition).find_each do |pr|
      pr.update!(some_field: new_value)
    end
    
    # 2. Fix any association issues
    # This is usually not needed due to callbacks, but good to be safe
    say "Updating week associations..."
    system "rake fix:week_associations"
    
    # 3. Recalculate statistics if needed
    say "Recalculating week statistics..."
    system "rake fix:week_stats"
  end
end
```

## Monitoring & Alerts

Consider setting up monitoring for:
- Week association validation failures
- Statistics calculation discrepancies  
- Deploy script data integrity warnings
- Large numbers of week association fixes needed

This ensures any data integrity issues are caught quickly and can be resolved before affecting users.