namespace :backfill do
  desc "Fill pull requests' branch names and flag promotions (safe to rerun)"
  task pull_request_refs: :environment do
    backfill = PullRequestRefsBackfill.new(GithubService.new(ENV.fetch('GITHUB_ACCESS_TOKEN')))
    Repository.order(:name).each { |repository| backfill.run(repository) }
    puts 'Next: rake weeks:update_stats, so cached weekly figures leave the promotions out'
  end
end
