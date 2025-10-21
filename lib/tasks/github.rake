namespace :github do
  desc "Fetch pull requests for a repository. Add 'fetch_all' to fetch all PRs."
  task :fetch_pull_requests => :environment do
    repo_name = ENV['REPO']
    fetch_all = ENV['FETCH_ALL'] == 'true'

    def print_usage
      puts "Usage:"
      puts "  rake github:fetch_pull_requests REPO=owner/repo"
      puts "  rake github:fetch_pull_requests REPO=owner/repo FETCH_ALL=true"
      puts
      puts "Arguments:"
      puts "  REPO: Name of the repository (e.g., 'owner/repo')"
      puts "  FETCH_ALL: Optional. Set to 'true' to fetch all pull requests instead of just new ones."
    end

    if repo_name.nil?
      puts "Error: Repository name is required."
      print_usage
      exit 1
    end

    puts "Fetching pull requests for #{repo_name}..."
    puts fetch_all ? "Fetching all pull requests." : "Fetching only new pull requests."

    # Queue the sync job
    SyncRepositoryJob.perform_later(repo_name, fetch_all: fetch_all)

    puts "Repository sync job queued. Check Sidekiq for progress."
  end
end
