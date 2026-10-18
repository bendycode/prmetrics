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

    tracker = Tracker.new(kind: :github_issues, source_repository: repository)
    tracker.key_prefix = args[:key_prefix] if args[:key_prefix].present?
    unless tracker.valid?
      puts "Error: #{tracker.errors.full_messages.to_sentence}"
      exit 1
    end

    ApplicationRecord.transaction do
      tracker.save!
      repository.update!(tracker: tracker)
    end
    puts "Created a GitHub issues tracker for #{repository.name}. Run rake sync:stories to read its issues."
  end

  desc 'Measure cycle time from a Shortcut workflow covering the named repositories: ' \
       'rake trackers:create_shortcut[workflow_id,owner/repo,owner/other]; the token comes from ' \
       'SHORTCUT_API_TOKEN or a hidden prompt'
  task :create_shortcut, %i[workflow_id] => :environment do |_t, args|
    names = args.extras
    if names.empty?
      puts 'Error: Name at least one repository for the tracker to cover.'
      exit 1
    end

    repositories = names.map do |name|
      repository = Repository.find_by(name: name)
      unless repository
        puts "Error: Repository #{name} not found. Add the repository before creating its tracker."
        exit 1
      end
      if repository.tracker
        puts "Error: #{repository.name} is already covered by tracker #{repository.tracker_id}"
        exit 1
      end
      repository
    end

    tracker = Tracker.new(kind: :shortcut, workflow_id: args[:workflow_id], api_token: TokenPrompt.read('SHORTCUT_API_TOKEN'))
    unless tracker.valid?
      puts "Error: #{tracker.errors.full_messages.to_sentence}"
      exit 1
    end

    ApplicationRecord.transaction do
      tracker.save!
      repositories.each { |repository| repository.update!(tracker: tracker) }
    end
    puts "Created Shortcut tracker #{tracker.id} covering #{repositories.map(&:name).to_sentence}. " \
         'Run rake sync:stories to read its stories.'
  end

  desc "Replace a tracker's API token: rake trackers:set_token[tracker_id]; the token comes from " \
       'SHORTCUT_API_TOKEN or a hidden prompt'
  task :set_token, %i[tracker_id] => :environment do |_t, args|
    tracker = Tracker.find_by(id: args[:tracker_id])
    unless tracker
      puts "Error: Tracker #{args[:tracker_id]} not found."
      exit 1
    end
    unless tracker.shortcut?
      puts "Error: Tracker #{tracker.id} is a #{tracker.kind} tracker, which reads with GITHUB_ACCESS_TOKEN."
      exit 1
    end

    tracker.api_token = TokenPrompt.read('SHORTCUT_API_TOKEN')
    unless tracker.save
      puts "Error: #{tracker.errors.full_messages.to_sentence}"
      exit 1
    end
    puts "Replaced the token for tracker #{tracker.id}."
  end
end
