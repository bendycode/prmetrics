# Reads merged pull requests and their mergers from GitHub's GraphQL API,
# which answers with 100 at a time where the REST endpoints answer with one.
module GithubMergedPullRequests
  MERGED_PULL_REQUESTS_QUERY = <<~GRAPHQL.freeze
    query($owner: String!, $name: String!, $after: String) {
      repository(owner: $owner, name: $name) {
        pullRequests(states: MERGED, first: 100, after: $after) {
          pageInfo { hasNextPage endCursor }
          nodes { number mergedBy { login __typename ... on User { databaseId } ... on Bot { databaseId } } }
        }
      }
    }
  GRAPHQL

  # One page of merged pull requests and their mergers, 100 at a time, as
  # {nodes: [{number:, merged_by:}], has_next_page:, end_cursor:}. GitHub's
  # REST endpoints answer with a merger one pull request at a time, which is
  # thousands of calls on a repository of any age.
  def merged_pull_requests(repo_name, after: nil)
    owner, name = repo_name.split('/')
    page = with_rate_limit_handling do
      response = @client.post('/graphql', { query: MERGED_PULL_REQUESTS_QUERY,
                                            variables: { owner: owner, name: name, after: after } }.to_json)
      merged_pull_requests_from(response, repo_name)
    end

    { nodes: page.nodes.map { |node| merged_pull_request(node) },
      has_next_page: page.pageInfo.hasNextPage,
      end_cursor: page.pageInfo.endCursor }
  end

  private

  # GitHub answers a GraphQL failure with a 200 and an errors array, so the
  # response has to be read before its data is trusted. A rate-limited query
  # arrives the same way, and is raised as the error the retry logic waits on.
  def merged_pull_requests_from(response, repo_name)
    errors = Array(response.errors)
    raise GithubRateLimiting::RateLimited if errors.any? { |error| error.type == 'RATE_LIMITED' }

    raise "GitHub rejected the query for #{repo_name}: #{errors.map(&:message).join('; ')}" if errors.any?

    repository = response.data&.repository
    raise "GitHub returned no repository named #{repo_name}; is it visible to this token?" unless repository

    repository.pullRequests
  end

  def merged_pull_request(node)
    merger = node.mergedBy
    merged_by = { login: merger.login, id: merger.databaseId, type: merger.__typename } if merger
    { number: node.number, merged_by: merged_by }
  end
end
