namespace :github do
  desc "Fetch and store pull requests for a repository"
  task :fetch_pull_requests, [:repo_name] => :environment do |t, args|
    repo_name = args[:repo_name]
    if repo_name.nil?
      puts "Please provide a repository name. Usage: rake github:fetch_pull_requests['owner/repo']"
    else
      service = GithubService.new(GITHUB_ACCESS_TOKEN)
      service.fetch_and_store_pull_requests(repo_name)
      puts "Pull requests fetched and stored for #{repo_name}"
    end
  end
end
