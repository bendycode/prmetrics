# Reads a repository's issues and their timelines from GitHub's REST API.
module GithubIssues
  # Every issue, open and closed. GitHub lists pull requests among the
  # issues, marked by a pull_request field, so they are left out here.
  def issues(repo_name)
    each_page { |page| @client.list_issues(repo_name, state: 'all', page: page, per_page: 100) }
      .reject(&:pull_request)
  end

  def issue_timeline(repo_name, number)
    each_page { |page| @client.issue_timeline(repo_name, number, page: page, per_page: 100) }
  end

  # Whether an issue missing from a listing has left the repository: deleted,
  # converted to a discussion, or transferred, which GitHub answers by
  # redirecting to the issue in its new repository.
  def issue_gone?(repo_name, number)
    issue = with_rate_limit_handling { @client.issue(repo_name, number) }
    !issue.repository_url.to_s.downcase.end_with?("/repos/#{repo_name.downcase}")
  rescue Octokit::NotFound, Octokit::Deprecated
    true
  end
end
