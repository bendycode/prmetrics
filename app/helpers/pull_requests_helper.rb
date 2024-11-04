module PullRequestsHelper
  def github_pr_url(pr)
    "#{pr.repository.url}/pull/#{pr.number}"
  end
end
