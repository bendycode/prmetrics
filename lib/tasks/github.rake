namespace :github do
  desc "Fetch and store pull requests for a repository"
  task :fetch_pull_requests, [:repo_name, :fetch_all] => :environment do |t, args|
    repo_name = args[:repo_name]
    fetc_all = args[:fetch_all] == 'true'

    if repo_name.nil?
      puts "Please provide a repository name. Usage: rake github:fetch_pull_requests['owner/repo']"
    else
      service = GithubService.new(GITHUB_ACCESS_TOKEN)

      puts "Fetching pull requests for #{repo_name}..."
      initial_count = PullRequest.count

      service.fetch_and_store_pull_requests(repo_name, fetch_all: fetch_all)

      final_count = PullRequest.count
      new_prs = final_count - initial_count

      puts "Pull requests fetched and stored for #{repo_name}"
      puts "#{new_prs} new pull requests added. Total pull requests: #{final_count}"
    end
  end
end
