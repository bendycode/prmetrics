namespace :weeks do
  desc "Generate week records for all repositories"
  task generate: :environment do
    Repository.find_each do |repository|
      generate_weeks_for_repository(repository)
    end
    puts "Week records generated successfully."
  end

  desc "Update statistics for all weeks and generate new weeks if necessary"
  task update_stats: :environment do
    Repository.find_each do |repository|
      generate_weeks_for_repository(repository)
    end
    WeekStatsService.update_all_weeks
    puts "Week statistics updated and new weeks generated successfully."
  end

  def generate_weeks_for_repository(repository)
    oldest_date = [
      repository.pull_requests.minimum(:gh_created_at),
      repository.pull_requests.minimum(:ready_for_review_at),
      repository.pull_requests.minimum(:gh_merged_at),
      repository.pull_requests.minimum(:gh_closed_at)
    ].compact.min

    return unless oldest_date

    start_date = oldest_date.beginning_of_week
    end_date = Date.today.end_of_week

    (start_date.to_date..end_date.to_date).step(7) do |date|
      week_begin = date.beginning_of_week
      week_end = date.end_of_week
      week_number = date.strftime('%Y%W').to_i
      repository.weeks.find_or_create_by!(week_number: week_number) do |week|
        week.begin_date = week_begin
        week.end_date = week_end
      end
    end
  end
end
