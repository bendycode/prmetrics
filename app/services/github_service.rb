class GithubService
  include GithubRateLimiting
  include GithubMergedPullRequests

  def initialize(access_token)
    @client = Octokit::Client.new(access_token: access_token)
    @client.auto_paginate = false
  end

  def get_pull_request_count(repo_name)
    # Get total count of PRs for progress tracking
    # Using search API which returns total_count
    with_rate_limit_handling do
      result = @client.search_issues("repo:#{repo_name} is:pr", per_page: 1)
      result.total_count
    end
  rescue StandardError => e
    Rails.logger.warn "Could not get PR count: #{e.message}"
    nil
  end

  def default_branch(repo_name)
    with_rate_limit_handling { @client.repository(repo_name).default_branch }
  end

  # Yields every pull request GitHub lists for the repository, open or closed,
  # oldest first: in the sync's updated-first order a pull request updated
  # during the walk moves to page one and pushes another off the page behind it.
  def each_pull_request(repo_name, &)
    page = 1
    loop do
      pull_requests = fetch_pull_requests_page(repo_name, page, order: { sort: 'created', direction: 'asc' })
      break if pull_requests.empty?

      pull_requests.each(&)
      page += 1
    end
  end

  # The processor is called with each pull request's GitHub data once it is
  # stored; it owns week associations and statistics. Returns the newest
  # update stored, which the caller records as the last fetch only once
  # everything that depends on the stored pull requests has finished.
  def fetch_and_store_pull_requests(repo_name, processor:, fetch_all: false)
    repository = Repository.find_by!(name: repo_name)
    cutoff = fetch_all ? nil : repository.last_fetched_at
    page = 1
    total_processed = 0
    most_recent_update = nil

    loop do
      listed_at = Time.current
      pull_requests = fetch_pull_requests_page(repo_name, page)
      # GitHub's list endpoint takes no since parameter, so the cutoff applies
      # here. Its timestamps are whole seconds, so a pull request updated in
      # the second the last fetch stopped at can arrive after that fetch
      # listed it.
      pull_requests = pull_requests.reject { |pr| pr.updated_at < cutoff } if cutoff
      break if pull_requests.empty?

      stored = fetch_all ? {} : stored_updates(repository, pull_requests)
      pull_requests.each do |pr|
        process_pull_request(repository, repo_name, pr, listed_at:) unless stored[pr.number] == pr.updated_at
        most_recent_update = [most_recent_update, pr.updated_at].compact.max
        Rails.logger.debug { "Processed PR ##{pr.number}" }
        total_processed += 1

        processor.call(pr)
      end

      page += 1
    end

    Rails.logger.info "Processed #{total_processed} pull requests for repository #{repository.id}"
    Rails.logger.info "Most recent update: #{most_recent_update}"
    most_recent_update
  end

  private

  def fetch_pull_requests_page(repo_name, page, order: { sort: 'updated', direction: 'desc' })
    options = { state: 'all', page: page, per_page: 100 }.merge(order)

    with_rate_limit_handling do
      @client.pull_requests(repo_name, options)
    end
  end

  # The update each listed pull request is stored at, by number. One stored at
  # the update GitHub lists has nothing new to fetch, whether an earlier sync
  # stored it or a failed one stored it before failing, once GitHub is known
  # to have listed it after that update. Rows stored without an author, which
  # a contributor that could not be saved leaves behind, are read again.
  def stored_updates(repository, pull_requests)
    repository.pull_requests.where(number: pull_requests.map(&:number))
              .listed_after_last_update
              .where.not(author_id: nil)
              .pluck(:number, :gh_updated_at).to_h
  end

  # Everything is read from GitHub before anything is written, and written in
  # one transaction, since a pull request stored at its current update is not
  # read again. The reads stay outside the transaction because a rate limit
  # can hold one for an hour.
  def process_pull_request(repository, repo_name, pr, listed_at:)
    events = events_worth_reading?(pr) ? issue_events(repo_name, pr.number) : []
    reviews = pull_request_reviews(repo_name, pr.number)

    ApplicationRecord.transaction do
      pull_request = store_pull_request(repository, pr, events, listed_at)
      store_reviews(pull_request, reviews)
      store_author(pull_request, pr)
    end
  end

  def store_pull_request(repository, pr, events, listed_at)
    pull_request = repository.pull_requests.find_or_initialize_by(number: pr.number)
    author = Contributor.find_or_create_from_github(pr.user)
    ready_for_review_at = pr.draft ? nil : ready_for_review_time(events, pr.created_at)

    pull_request.update!(
      title: pr.title,
      state: pr.state,
      draft: pr.draft,
      author: author,
      gh_created_at: pr.created_at,
      gh_updated_at: pr.updated_at,
      listed_at: listed_at,
      gh_merged_at: pr.merged_at,
      gh_closed_at: pr.closed_at,
      ready_for_review_at: ready_for_review_at,
      base_ref: pr.base.ref,
      head_ref: pr.head.ref,
      head_repository: pr.head.repo&.full_name,
      **merger_attribute(pr, events)
    )
    pull_request
  end

  # An open draft has neither event this reads: it has not left draft, and a
  # draft cannot be merged without leaving it first.
  def events_worth_reading?(pull_request)
    !pull_request.draft || pull_request.merged_at
  end

  # GitHub serves a pull request's events oldest first, 30 to a page by
  # default, so the events this sync reads -- ready_for_review, and the merge
  # -- are the ones a busy pull request pushes off the first page.
  def issue_events(repo_name, pr_number)
    each_page { |page| @client.issue_events(repo_name, pr_number, page: page, per_page: 100) }
  end

  # Everything GitHub serves for a pull request, page by page. Its endpoints
  # answer 30 at a time by default, and the client does not paginate itself.
  def each_page
    collected = []
    page = 1
    loop do
      batch = with_rate_limit_handling { yield(page) }
      collected.concat(batch)
      break if batch.size < 100

      page += 1
    end
    collected
  end

  # A pull request opened ready for review has no ready_for_review event
  def ready_for_review_time(events, created_at)
    events.find { |event| event.event == 'ready_for_review' }&.created_at || created_at
  end

  # GitHub reports no actor on the merge event of some merges by accounts that
  # have since been deleted, and the backfill reads the merger from a different
  # endpoint, so a merger already recorded is left alone rather than erased.
  def merger_attribute(pr, events)
    return { merged_by: nil } unless pr.merged_at

    merger = merger_of(events)
    merger ? { merged_by: merger } : {}
  end

  # GitHub's merge event names whoever pressed Merge, which is the actor that
  # enabled auto-merge when the merge came from the queue.
  def merger_of(events)
    actor = events.find { |event| event.event == 'merged' }&.actor
    return nil unless actor

    # A contributor whose username is already taken comes back unsaved, and
    # belongs_to would write that as no merger at all
    contributor = find_or_create_contributor(actor)
    contributor if contributor&.persisted?
  end

  def pull_request_reviews(repo_name, pr_number)
    each_page { |page| @client.pull_request_reviews(repo_name, pr_number, page: page, per_page: 100) }
  end

  # Every submitted review is stored; the metrics decide which ones count
  def store_reviews(pull_request, reviews)
    reviews.each do |review|
      next if review.submitted_at.nil?

      author = find_or_create_contributor(review.user)
      review_record = pull_request.reviews.find_or_initialize_by(
        state: review.state,
        submitted_at: review.submitted_at,
        author: author
      )
      review_record.save!
    end
  end

  def find_or_create_contributor(github_user)
    # For API responses that have full data including github_id
    if github_user.respond_to?(:id) && github_user.id
      Contributor.find_or_create_from_github(github_user)
    else
      # Fallback for cases where we only have username
      Contributor.find_or_create_from_username(github_user.login, {
                                                 name: github_user.respond_to?(:name) ? github_user.name : nil,
                                                 email: github_user.respond_to?(:email) ? github_user.email : nil
                                               })
    end
  end

  # The author's participation row, which the contributor pages read. The
  # merger lives on the pull request itself; GitHub's list payload, the only
  # place this ever looked for one, does not carry it.
  def store_author(pull_request, pr)
    store_user(pull_request, pr.user, 'author')
  end

  def store_user(pull_request, github_user, role)
    return unless github_user

    contributor = find_or_create_contributor(github_user)

    PullRequestUser.find_or_create_by(
      pull_request: pull_request,
      user: contributor,
      role: role
    )
  end
end
