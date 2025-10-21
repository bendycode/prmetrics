namespace :timezone do
  desc 'Recalculate all week boundaries and associations using Central Time'
  task fix_weeks: :environment do
    puts '🕐 Starting timezone fix for all repositories...'

    Repository.find_each do |repository|
      puts "\n📁 Processing repository: #{repository.name}"

      # Step 1: Backup current week count
      original_week_count = repository.weeks.count
      puts "  Current weeks: #{original_week_count}"

      # Step 2: Collect all PR dates that need week associations
      pr_dates = collect_pr_dates(repository)
      puts "  Found #{pr_dates.size} unique dates needing weeks"

      # Step 3: Create correct week records using Central Time
      correct_weeks = create_correct_weeks(repository, pr_dates)
      puts "  Created/verified #{correct_weeks.size} week records"

      # Step 4: Update all PR week associations
      updated_prs = update_pr_associations(repository)
      puts "  Updated #{updated_prs} pull request associations"

      # Step 5: Clean up orphaned weeks
      orphaned = cleanup_orphaned_weeks(repository)
      puts "  Removed #{orphaned} orphaned weeks"

      # Step 6: Recalculate statistics for all weeks
      WeekStatsService.new(repository.weeks.each).map(&:update_stats)
      puts '  Recalculated statistics for all weeks'

      final_week_count = repository.weeks.count
      puts "  Final weeks: #{final_week_count} (#{final_week_count - original_week_count} net change)"
    end

    puts "\n✅ Timezone fix completed for all repositories!"
  end

  desc 'Preview timezone fix changes without applying them'
  task preview: :environment do
    puts '🔍 Previewing timezone fix changes...'

    Repository.find_each do |repository|
      puts "\n📁 Repository: #{repository.name}"

      # Analyze current week structure
      current_weeks = repository.weeks.order(:week_number)
      puts "  Current weeks: #{current_weeks.count}"

      # Find potential issues
      issues = analyze_week_issues(repository)

      if issues.any?
        puts '  ⚠️  Issues found:'
        issues.each { |issue| puts "    - #{issue}" }
      else
        puts '  ✅ No timezone issues detected'
      end

      # Show sample of what would change
      show_sample_changes(repository)
    end
  end

  private

  def collect_pr_dates(repository)
    dates = Set.new

    repository.pull_requests.find_each do |pr|
      [pr.gh_created_at, pr.ready_for_review_at, pr.gh_merged_at, pr.gh_closed_at].compact.each do |date|
        dates << date
      end
    end

    dates
  end

  def create_correct_weeks(repository, dates)
    week_map = {}

    dates.each do |date|
      ct_date = date.in_time_zone('America/Chicago')
      week_number = ct_date.strftime('%Y%W').to_i

      next if week_map[week_number]

      week = repository.weeks.find_or_initialize_by(week_number: week_number)
      week.begin_date = ct_date.beginning_of_week.to_date
      week.end_date = ct_date.end_of_week.to_date
      week.save!
      week_map[week_number] = week
    end

    week_map.values
  end

  def update_pr_associations(repository)
    updated_count = 0

    repository.pull_requests.find_each do |pr|
      pr.update_week_associations
      updated_count += 1
    end

    updated_count
  end

  def cleanup_orphaned_weeks(repository)
    # Find weeks with no PR associations
    orphaned_weeks = repository.weeks.left_joins(
      :ready_for_review_prs, :first_review_prs, :merged_prs, :closed_prs
    ).where(
      pull_requests: { id: nil }
    ).distinct

    count = orphaned_weeks.count
    orphaned_weeks.destroy_all
    count
  end

  def analyze_week_issues(repository)
    issues = []

    # Check for weeks with potential timezone boundary issues
    repository.weeks.find_each do |week|
      # Recalculate what the week boundaries should be
      sample_date = week.begin_date.in_time_zone('America/Chicago')
      correct_begin = sample_date.beginning_of_week.to_date
      correct_end = sample_date.end_of_week.to_date

      if week.begin_date != correct_begin || week.end_date != correct_end
        issues << "Week #{week.week_number}: boundaries #{week.begin_date} to #{week.end_date} should be #{correct_begin} to #{correct_end}"
      end
    end

    issues
  end

  def show_sample_changes(repository)
    # Show first few weeks that would change
    sample_weeks = repository.weeks.limit(3)

    puts '  Sample changes:'
    sample_weeks.each do |week|
      sample_date = week.begin_date.in_time_zone('America/Chicago')
      correct_begin = sample_date.beginning_of_week.to_date
      correct_end = sample_date.end_of_week.to_date

      if week.begin_date != correct_begin || week.end_date != correct_end
        puts "    Week #{week.week_number}: #{week.begin_date}-#{week.end_date} → #{correct_begin}-#{correct_end}"
      else
        puts "    Week #{week.week_number}: #{week.begin_date}-#{week.end_date} (no change)"
      end
    end
  end
end
