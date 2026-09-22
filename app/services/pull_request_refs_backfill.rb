# Fills the base and head branch names, and the repository's default branch,
# that the sync began recording after these pull requests were stored, then
# flags the promotions among them. Safe to rerun: a pull request whose branch
# names are already filled is left alone.
class PullRequestRefsBackfill
  def initialize(github_service, output: $stdout)
    @github_service = github_service
    @output = output
  end

  def run(repository)
    repository.update!(default_branch: @github_service.default_branch(repository.name))
    unfilled = repository.pull_requests.where(base_ref: nil).index_by(&:number)

    filled = 0
    @github_service.each_pull_request(repository.name) do |pr|
      pull_request = unfilled[pr.number] or next

      pull_request.update!(base_ref: pr.base.ref, head_ref: pr.head.ref)
      filled += 1
    end

    promotions = repository.refresh_promotions!.count(&:promotion?)
    @output.puts "#{repository.name}: filled #{filled} #{'pull request'.pluralize(filled)}, " \
                 "flagged #{promotions} #{'promotion'.pluralize(promotions)}"
  end
end
