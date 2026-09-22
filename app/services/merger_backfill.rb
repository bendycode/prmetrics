# Records who merged each pull request stored before the sync read the merge
# event. Reads GitHub's GraphQL API, which answers with 100 pull requests'
# mergers per call, where the events endpoint answers one pull request per
# call. Safe to rerun: a pull request whose merger is known is left alone, and
# a repository with none left to fill is not asked about at all.
class MergerBackfill
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
    unknown = repository.pull_requests.merged.where(merged_by_id: nil).index_by(&:number)
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
    nodes.count do |node|
      pull_request = unknown.delete(node[:number])
      next false unless pull_request && node[:merged_by]

      pull_request.update!(merged_by: contributor_for(node[:merged_by]))
    end
  end

  # A merger GitHub no longer knows (a deleted account) comes back without a
  # login, and that pull request keeps no merger.
  def contributor_for(merger)
    Contributor.find_or_create_from_github(
      Struct.new(:id, :login, :name, :avatar_url, :email, :type)
            .new(merger[:id], merger[:login], nil, nil, nil, merger[:type])
    )
  end
end
