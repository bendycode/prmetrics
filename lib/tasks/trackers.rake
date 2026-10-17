namespace :trackers do
  desc 'Measure cycle time from a repository\'s own GitHub issues: rake trackers:create_github_issues[owner/repo,PRM]'
  task :create_github_issues, %i[repo_name key_prefix] => :environment do |_t, args|
    repository = Repository.find_by(name: args[:repo_name])
    unless repository
      puts "Error: Repository #{args[:repo_name]} not found. Add the repository before creating its tracker."
      exit 1
    end

    if repository.issue_tracker
      puts "#{repository.name} already has a GitHub issues tracker"
      next
    end

    if repository.tracker
      puts "Error: #{repository.name} is already covered by tracker #{repository.tracker_id}"
      exit 1
    end

    config = args[:key_prefix].present? ? { 'key_prefix' => args[:key_prefix] } : {}
    ApplicationRecord.transaction do
      tracker = Tracker.create!(kind: :github_issues, source_repository: repository, config: config)
      repository.update!(tracker: tracker)
    end
    puts "Created a GitHub issues tracker for #{repository.name}. Run rake sync:stories to read its issues."
  end
end
