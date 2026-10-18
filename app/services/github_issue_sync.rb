# Reads a GitHub issues tracker's issues and their timelines into stories,
# then measures every story in the tracker again from its events.
class GithubIssueSync
  # Raised once a sync has stored and measured every issue it could, naming
  # the ones it could not.
  class IssuesFailed < StandardError; end

  # Raised before any GitHub call when the token the sync reads with is unset.
  class MissingToken < StandardError
    def initialize(msg = 'GITHUB_ACCESS_TOKEN environment variable is not set')
      super
    end
  end

  # full reads every issue's timeline, unchanged ones included, as after a
  # change in how events are read
  def initialize(tracker, github: nil, full: false)
    @tracker = tracker
    @full = full
    @github = github || GithubService.new(ENV.fetch('GITHUB_ACCESS_TOKEN', nil).presence || raise(MissingToken))
    @repo_name = tracker.source_repository.name
  end

  def sync!
    listed_at = Time.current
    issues = @github.issues(@repo_name)
    stored = stored_updates(issues)

    failures = issues.filter_map do |issue|
      store_issue(issue, listed_at) unless !@full && unchanged?(issue, stored)
      nil
    rescue StandardError => e
      # The class alone: production logs reach the nightly workflow's public
      # log, and a GitHub error's message quotes the repository's URL.
      Rails.logger.error "Story sync could not store issue ##{issue.number}: #{e.class}"
      "##{issue.number} (#{e.class})"
    end
    measure_stories
    mark_gone(issues)
    raise IssuesFailed, "Could not store issues #{failures.join(', ')}" if failures.any?
  end

  private

  # A closed issue stored at the update GitHub lists has nothing new to read,
  # once GitHub is known to have listed it after that update. An open issue
  # is always read: a commit or pull request that mentions it adds to its
  # timeline without moving its updated_at, and closing it does move it.
  def unchanged?(issue, stored)
    issue.state == 'closed' && stored[issue.number.to_s] == issue.updated_at
  end

  # The update each listed issue is stored at. A gone story listed again is
  # read again, which brings it back.
  def stored_updates(issues)
    @tracker.stories.where(external_id: listed_ids(issues), gone: false)
            .listed_after_last_update
            .pluck(:external_id, :source_updated_at).to_h
  end

  # Everything is read from GitHub before anything is written, and written
  # in one transaction, since a story stored at its current update is not
  # read again. The read stays outside the transaction because a rate limit
  # can hold one for an hour.
  def store_issue(issue, listed_at)
    timeline = @github.issue_timeline(@repo_name, issue.number)
    events = GithubIssueTimeline.new(repo_name: @repo_name, issue: issue, timeline: timeline).events

    ApplicationRecord.transaction do
      story = @tracker.stories.find_or_initialize_by(external_id: issue.number.to_s)
      story.update!(story_attributes(issue, listed_at))
      story.record_events(events)
    end
  end

  def story_attributes(issue, listed_at)
    {
      key: @tracker.story_key(issue.number),
      title: issue.title,
      url: issue.html_url,
      state: issue.state,
      state_reason: issue.state_reason,
      source_created_at: issue.created_at,
      source_updated_at: issue.updated_at,
      listed_at: listed_at,
      gone: false
    }
  end

  # An issue GitHub no longer lists was transferred, deleted, or converted
  # to a discussion. Listing every issue on each sync is what tells it apart
  # from one that hasn't changed. The listing pages by number over a set
  # that can change while it runs, so a missing issue is read on its own
  # before it is marked gone.
  def mark_gone(issues)
    @tracker.stories.where(gone: false).where.not(external_id: listed_ids(issues)).find_each do |story|
      story.update!(gone: true) if @github.issue_gone?(@repo_name, story.external_id.to_i)
    end
  end

  def listed_ids(issues)
    issues.map { |issue| issue.number.to_s }
  end

  def measure_stories
    @tracker.stories.includes(:events).find_each do |story|
      story.measure(@tracker.triggers)
    end
  end
end
