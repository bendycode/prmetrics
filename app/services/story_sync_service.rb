# Reads a GitHub issues tracker's issues and their timelines into stories,
# then measures every story in the tracker again from its events.
class StorySyncService
  def initialize(tracker, github: GithubService.new(ENV.fetch('GITHUB_ACCESS_TOKEN', nil)))
    @tracker = tracker
    @github = github
    @repo_name = tracker.source_repository.name
  end

  def sync!
    listed_at = Time.current
    issues = @github.issues(@repo_name)
    stored = stored_updates(issues)

    issues.each do |issue|
      store_issue(issue, listed_at) unless stored[issue.number.to_s] == issue.updated_at
    end
    mark_gone(issues)
    measure_stories
  end

  private

  # The update each listed issue is stored at. One stored at the update
  # GitHub lists has nothing new to read, once GitHub is known to have listed
  # it after that update. Every issue is listed on each sync, so this is what
  # keeps a sync from reading every timeline again. A gone story listed again
  # is read again, which brings it back.
  def stored_updates(issues)
    @tracker.stories.where(external_id: listed_ids(issues), gone: false)
            .listed_after_last_update
            .pluck(:external_id, :gh_updated_at).to_h
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
      gh_created_at: issue.created_at,
      gh_updated_at: issue.updated_at,
      listed_at: listed_at,
      gone: false
    }
  end

  # An issue GitHub no longer lists was transferred, deleted, or converted
  # to a discussion. Listing every issue on each sync is what tells it apart
  # from one that hasn't changed.
  def mark_gone(issues)
    @tracker.stories.where(gone: false).where.not(external_id: listed_ids(issues)).find_each do |story|
      story.update!(gone: true)
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
