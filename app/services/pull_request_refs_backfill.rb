# Fills the base and head branch names, and the repository's default branch,
# that the sync began recording after these pull requests were stored, then
# flags the promotions among them. Safe to rerun: a pull request whose branch
# names are already filled is left alone, and a repository with none left to
# fill does not walk GitHub's pull request list at all.
class PullRequestRefsBackfill
  def initialize(github_service, output: $stdout)
    @github_service = github_service
    @output = output
  end

  def run(repository)
    branch = @github_service.default_branch(repository.name)
    repository.update!(default_branch: branch) if branch.present?

    filled = fill_branch_names(repository)
    promotions = repository.refresh_promotions!.count(&:promotion?)
    @output.puts "#{repository.name}: filled #{filled} #{'pull request'.pluralize(filled)}, " \
                 "flagged #{promotions} #{'promotion'.pluralize(promotions)}"
  end

  private

  def fill_branch_names(repository)
    unfilled = repository.pull_requests.where(base_ref: nil).index_by(&:number)
    return 0 if unfilled.empty?

    filled = 0
    @github_service.each_pull_request(repository.name) do |pr|
      pull_request = unfilled.delete(pr.number)
      next unless pull_request

      pull_request.update!(base_ref: pr.base.ref, head_ref: pr.head.ref,
                           head_repository: pr.head.repo&.full_name)
      filled += 1
      break if unfilled.empty?
    end
    filled
  end
end
