namespace :weeks do
  desc 'Generate week records for all repositories'
  task generate: :environment do
    Repository.find_each do |repository|
      WeekStatsService.generate_weeks_for_repository(repository)
    end
    puts 'Week records generated successfully.'
  end

  desc 'Update statistics for all weeks and generate new weeks if necessary'
  task update_stats: :environment do
    Repository.find_each do |repository|
      WeekStatsService.generate_weeks_for_repository(repository)
    end
    WeekStatsService.update_all_weeks
    puts 'Week statistics updated and new weeks generated successfully.'
  end
end
