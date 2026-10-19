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

    if repository.tracker_id
      puts "Error: #{repository.name} is already covered by tracker #{repository.tracker_id}"
      exit 1
    end

    tracker = Tracker.new(kind: :github_issues, source_repository: repository)
    tracker.key_prefix = args[:key_prefix] if args[:key_prefix].present?
    unless tracker.valid?
      puts "Error: #{tracker.errors.full_messages.to_sentence}"
      exit 1
    end

    begin
      TrackerCoverage.cover!(tracker, [repository])
    rescue TrackerCoverage::AlreadyCovered => e
      puts "Error: #{e.message}"
      exit 1
    end
    puts "Created a GitHub issues tracker for #{repository.name}. Run rake sync:stories to read its issues."
  end

  desc 'Measure cycle time from a Shortcut workflow covering the named repositories: ' \
       'rake trackers:create_shortcut[workflow_id,owner/repo,owner/other]; the token comes from ' \
       'SHORTCUT_API_TOKEN or a hidden prompt'
  task :create_shortcut, %i[workflow_id] => :environment do |_t, args|
    names = args.extras.uniq
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
      if repository.tracker_id
        puts "Error: #{repository.name} is already covered by tracker #{repository.tracker_id}"
        exit 1
      end
      repository
    end

    # Everything but the token, the keys it is stored with included, is checked
    # before a person is asked to paste one
    unless Tracker.token_encryption_configured?
      puts 'Error: The Active Record encryption keys are not set. CLAUDE.md says how to set them.'
      exit 1
    end

    tracker = Tracker.new(kind: :shortcut, workflow_id: args[:workflow_id])
    tracker.validate
    refused = tracker.errors.attribute_names - [:api_token]
    if refused.any?
      puts "Error: #{refused.flat_map { |attribute| tracker.errors.full_messages_for(attribute) }.to_sentence}"
      exit 1
    end

    tracker.api_token = TokenPrompt.read('SHORTCUT_API_TOKEN')
    unless tracker.valid?
      puts "Error: #{tracker.errors.full_messages.to_sentence}"
      exit 1
    end

    begin
      TrackerCoverage.cover!(tracker, repositories)
    rescue TrackerCoverage::AlreadyCovered => e
      puts "Error: #{e.message}"
      exit 1
    end
    puts "Created Shortcut tracker #{tracker.id} covering #{repositories.map(&:name).to_sentence}. " \
         'Run rake sync:stories to read its stories.'
  end

  desc "Replace a tracker's API token: rake trackers:set_token[tracker_id]; the token comes from " \
       'SHORTCUT_API_TOKEN or a hidden prompt'
  task :set_token, %i[tracker_id] => :environment do |_t, args|
    if args[:tracker_id].blank?
      puts 'Usage: rake trackers:set_token[tracker_id]'
      exit 1
    end

    tracker = Tracker.find_by(id: args[:tracker_id])
    unless tracker
      puts "Error: Tracker #{args[:tracker_id]} not found."
      exit 1
    end
    unless tracker.shortcut?
      puts "Error: Tracker #{tracker.id} is a #{tracker.kind} tracker, which reads with GITHUB_ACCESS_TOKEN."
      exit 1
    end

    unless Tracker.token_encryption_configured?
      puts 'Error: The Active Record encryption keys are not set. CLAUDE.md says how to set them.'
      exit 1
    end

    # The new token is encrypted here and saved with encryption off, so the
    # save never decrypts the stored one to compare: after the keys change
    # that raises, and replacing every token after a key change is what this
    # task is for. Validations still run.
    ciphertext = Tracker.type_for_attribute(:api_token).serialize(TokenPrompt.read('SHORTCUT_API_TOKEN'))
    saved = ActiveRecord::Encryption.without_encryption do
      tracker.api_token = ciphertext
      tracker.save
    end
    unless saved
      puts "Error: #{tracker.errors.full_messages.to_sentence}"
      exit 1
    end
    puts "Replaced the token for tracker #{tracker.id}."
  end

  desc "Limit a Shortcut tracker to some of its workflow's teams: rake trackers:set_teams[tracker_id,team_id,...]; " \
       'name no team to read every team again'
  task :set_teams, %i[tracker_id] => :environment do |_t, args|
    if args[:tracker_id].blank?
      puts 'Usage: rake trackers:set_teams[tracker_id,team_id,...]'
      exit 1
    end

    tracker = Tracker.find_by(id: args[:tracker_id])
    unless tracker
      puts "Error: Tracker #{args[:tracker_id]} not found."
      exit 1
    end
    unless tracker.shortcut?
      puts "Error: Tracker #{tracker.id} is a #{tracker.kind} tracker, which has no teams."
      exit 1
    end

    # A mistyped ID would leave the tracker reading no story at all
    teams = args.extras.compact_blank.uniq
    on_workflow = ShortcutService.new(tracker.api_token).groups
                                 .select { |group| group['workflow_ids'].include?(tracker.workflow_id.to_i) }
                                 .pluck('id')
    unknown = teams - on_workflow
    if unknown.any?
      puts "Error: #{unknown.to_sentence} #{unknown.one? ? 'is not a team' : 'are not teams'} on workflow #{tracker.workflow_id}."
      exit 1
    end

    # The lock reloads the tracker first, so a sync's write to its config is kept
    tracker.with_lock { tracker.update!(team_ids: teams.presence) }
    reach = teams.empty? ? 'every team' : "#{teams.size} #{'team'.pluralize(teams.size)}"
    puts "Tracker #{tracker.id} now reads the stories of #{reach}. Run rake sync:stories to apply it."
  end
end
