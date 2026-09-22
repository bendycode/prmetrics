# Records who merged each pull request stored before the sync read the merge
# event. Reads GitHub's GraphQL API, which answers with 100 pull requests'
# mergers per call, where the events endpoint answers one pull request per
# call. Safe to rerun: a pull request whose merger is known is left alone, and
# a repository with none left to fill is not asked about at all.
class MergerBackfill
  # The fields Contributor.find_or_create_from_github reads off Octokit's user
  GithubUser = Struct.new(:id, :login, :type) do
    def name = nil
    def avatar_url = nil
    def email = nil
  end

  def initialize(github_service, output: $stdout)
    @github_service = github_service
    @output = output
  end

  def run(repository)
    recorded = record_mergers(repository)
    @output.puts "#{repository.name}: recorded #{recorded} #{'merger'.pluralize(recorded)}"
  end

  private

  def record_mergers(repository)
    unknown = repository.pull_requests.missing_merger.index_by(&:number)
    return 0 if unknown.empty?

    recorded = 0
    cursor = nil
    loop do
      page = @github_service.merged_pull_requests(repository.name, after: cursor)
      recorded += record_page(page[:nodes], unknown)
      break if unknown.empty? || !page[:has_next_page]

      cursor = page[:end_cursor]
    end
    recorded
  end

  def record_page(nodes, unknown)
    recorded = 0
    nodes.each do |node|
      pull_request = unknown.delete(node[:number])
      next unless pull_request

      contributor = contributor_for(node[:merged_by])
      next unless contributor

      pull_request.update!(merged_by: contributor)
      recorded += 1
    end
    recorded
  end

  # GitHub reports no merger for a deleted account, and no id for an account
  # type the query does not ask one of, such as an imported mannequin. Either
  # way that pull request keeps no merger rather than an empty contributor.
  def contributor_for(merger)
    return nil if merger.blank? || merger[:id].blank? || merger[:login].blank?

    Contributor.find_or_create_from_github(GithubUser.new(*merger.values_at(:id, :login, :type)))
  end
end
