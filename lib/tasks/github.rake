namespace :github do
  desc "Fetch pull requests for a repository. Use 'fetch_all' as second argument to fetch all PRs."
  task :fetch_pull_requests, [:repo_name, :fetch_all] => :environment do |t, args|
    repo_name = args[:repo_name]
    fetch_all_arg = args[:fetch_all]

    def print_usage
      puts "Usage:"
      puts "  rake github:fetch_pull_requests['repository_name']"
      puts "  rake github:fetch_pull_requests['repository_name','fetch_all']"
      puts ""
      puts "Arguments:"
      puts "  repository_name: Name of the repository (e.g., 'owner/repo')"
      puts "  fetch_all: Optional. Use 'fetch_all' to fetch all pull requests instead of just new ones."
    end

    if repo_name.nil?
      puts "Error: Repository name is required."
      print_usage
      exit 1
    end

    if !fetch_all_arg.nil? && fetch_all_arg != 'fetch_all'
      puts "Error: Invalid second argument. Use 'fetch_all' to fetch all pull requests."
      print_usage
      exit 1
    end

    fetch_all = fetch_all_arg == 'fetch_all'

    puts "Fetching pull requests for #{repo_name}..."
    puts fetch_all ? "Fetching all pull requests." : "Fetching only new pull requests."

    service = GithubService.new(ENV['GITHUB_ACCESS_TOKEN'])
    service.fetch_and_store_pull_requests(repo_name, fetch_all: fetch_all)

    puts "Finished fetching pull requests."
  end
end
