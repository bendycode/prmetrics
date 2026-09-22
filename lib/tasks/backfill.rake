namespace :backfill do
  desc "Fill pull requests' branch names and flag promotions (safe to rerun)"
  task pull_request_refs: :environment do
    backfill = PullRequestRefsBackfill.new(GithubService.new(ENV.fetch('GITHUB_ACCESS_TOKEN')))
    Repository.order(:name).each { |repository| backfill.run(repository) }
    puts 'Next: weeks:update_stats, so cached weekly figures leave the promotions out'
  end

  desc 'Record who merged each pull request merged before the sync read it (safe to rerun)'
  task mergers: :environment do
    backfill = MergerBackfill.new(GithubService.new(ENV.fetch('GITHUB_ACCESS_TOKEN')))
    Repository.order(:name).each { |repository| backfill.run(repository) }
    puts 'Next: weeks:update_stats, so self-merged pull requests count toward their weeks'
  end
end
