namespace :github do
  desc "Fetch pull requests for a repository. Add 'fetch_all' to fetch all PRs."
  task :fetch_pull_requests, [:repo_name, :fetch_all] => :environment do |t, args|
    repo_name = args[:repo_name] || ARGV[1]
    fetch_all = args[:fetch_all] == 'fetch_all' || ARGV[2] == 'fetch_all'

    def print_usage
      puts "Usage:"
      puts "  rake github:fetch_pull_requests repository_name"
      puts "  rake github:fetch_pull_requests repository_name fetch_all"
      puts ""
      puts "Arguments:"
      puts "  repository_name: Name of the repository (e.g., 'owner/repo')"
      puts "  fetch_all: Optional. Add 'fetch_all' to fetch all pull requests instead of just new ones."
    end

    if repo_name.nil?
      puts "Error: Repository name is required."
      print_usage
      exit 1
    end

    puts "Fetching pull requests for #{repo_name}..."
    puts fetch_all ? "Fetching all pull requests." : "Fetching only new pull requests."

    service = GithubService.new(ENV['GITHUB_ACCESS_TOKEN'])
    service.fetch_and_store_pull_requests(repo_name, fetch_all: fetch_all)

    puts "Finished fetching pull requests."
  end
end

# This line allows additional arguments to be passed to the task
task(:fetch_pull_requests).arg_names << :fetch_all
