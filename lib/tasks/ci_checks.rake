namespace :ci do
  desc "Run all CI checks (coverage and data integrity)"
  task all: [:coverage_check, :data_integrity]

  desc "Run coverage ratcheting check for CI"
  task coverage_check: :environment do
    Rake::Task['coverage:ratchet'].invoke
  end

  desc "Run data integrity checks suitable for CI/CD pipeline"
  task data_integrity: :environment do
    puts "🔍 Running data integrity checks..."

    issues_found = 0

    # Check 1: Week associations consistency
    puts "\n1. Checking week associations..."

    # Sample a subset of PRs for performance in CI
    sample_size = [PullRequest.count / 10, 100].max
    sample_prs = PullRequest.limit(sample_size).includes(:merged_week, :ready_for_review_week)

    inconsistent_count = 0
    sample_prs.each do |pr|
      if pr.gh_merged_at
        expected_week = Week.find_by_date(pr.gh_merged_at)
        if pr.merged_week != expected_week
          inconsistent_count += 1
        end
      end
    end

    if inconsistent_count > 0
      puts "   ❌ Found #{inconsistent_count} PRs with inconsistent week associations in sample"
      issues_found += 1
    else
      puts "   ✅ Week associations look consistent"
    end

    # Check 2: Statistics consistency
    puts "\n2. Checking week statistics consistency..."

    # Sample a few recent weeks
    recent_weeks = Week.joins(:repository)
                      .where('begin_date > ?', 1.month.ago)
                      .limit(10)

    stats_inconsistent = 0
    recent_weeks.each do |week|
      actual_merged = week.repository.pull_requests.where(merged_week_id: week.id).count
      if week.num_prs_merged != actual_merged
        stats_inconsistent += 1
      end
    end

    if stats_inconsistent > 0
      puts "   ❌ Found #{stats_inconsistent} weeks with inconsistent statistics"
      issues_found += 1
    else
      puts "   ✅ Week statistics look consistent"
    end

    # Check 3: Orphaned records
    puts "\n3. Checking for orphaned records..."

    orphaned_contributors = Contributor.left_joins(:authored_pull_requests, :reviews, :pull_request_users)
                                      .where(pull_requests: { id: nil })
                                      .where(reviews: { id: nil })
                                      .where(pull_request_users: { id: nil })
                                      .count

    if orphaned_contributors > 0
      puts "   ⚠️  Found #{orphaned_contributors} orphaned contributors"
      # This is a warning, not a critical error
    else
      puts "   ✅ No orphaned contributors found"
    end

    # Summary
    puts "\n📊 Data Integrity Check Summary:"
    if issues_found == 0
      puts "   ✅ All checks passed!"
      exit 0
    else
      puts "   ❌ Found #{issues_found} critical issues"
      puts "\n🔧 Recommended actions:"
      puts "   - Run: rake fix:week_associations"
      puts "   - Run: rake fix:week_stats"
      puts "   - Check recent deployments for data consistency"
      exit 1
    end
  end
end