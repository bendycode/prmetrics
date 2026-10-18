# Reads a Shortcut tracker's workflow, every story in it, and each changed
# story's history into stories, then measures every story in the tracker
# again from its events.
class ShortcutStorySync
  # Raised once a sync has stored and measured every story it could, naming
  # the ones it could not.
  class StoriesFailed < StandardError; end

  # Each request already retries for over two minutes, so failures this many
  # stories in a row mean Shortcut is down, not one story is unreadable
  FAILURES_IN_A_ROW_LIMIT = 3

  # full reads every story's history, unchanged ones included, as after a
  # change in how events are read
  def initialize(tracker, shortcut: ShortcutService.new(tracker.api_token), full: false)
    @tracker = tracker
    @full = full
    @shortcut = shortcut
  end

  def sync!
    @listed_at = Time.current
    @workflow = @shortcut.workflow(@tracker.workflow_id)
    @done_states = @workflow['states'].select { |state| state['type'] == 'done' }.pluck('id')
    # Moving, adding, or retyping a state changes what stored moves mean, and
    # touches no story, so a changed set of states has every story read again
    @read_all = @full || states_digest != @tracker.workflow_digest
    listed = @workflow['states'].flat_map { |state| @shortcut.stories_in_state(state['id']) }
    stories, other_teams = listed.partition { |story| @tracker.reads_team?(story['group_id']) }

    failures, stopped = store_changed(stories)
    failures += mark_gone(stories, other_teams) unless stopped
    @tracker.measure_stories
    record_workflow if failures.empty?
    report(failures, stopped)
  end

  private

  # The states each move's committed flag is read from
  def states_digest
    Digest::SHA256.hexdigest(@workflow['states'].map { |state| state.values_at('id', 'type', 'position') }
                                                .sort_by(&:first).to_json)
  end

  # Only once every story was read: one that failed keeps the payload of the
  # workflow before. The lock reloads the tracker first, so a team limit set
  # while the sync ran is kept.
  def record_workflow
    @tracker.with_lock { @tracker.update!(workflow_digest: states_digest) }
  end

  # Everything about a story is read from Shortcut before it is written, and
  # written in one transaction, since a story stored at its current update
  # is not read again.
  def store_changed(stories)
    stored = @tracker.stored_updates(stories.map { |story| story['id'].to_s })
    failures = []
    in_a_row = 0
    stories.each do |story|
      next if unchanged?(story, stored)

      store_story(story)
      in_a_row = 0
    rescue StandardError => e
      failures << failure(story['id'], e)
      in_a_row += 1
      return [failures, true] if in_a_row >= FAILURES_IN_A_ROW_LIMIT
    end
    [failures, false]
  end

  # A story stored at the update Shortcut lists has nothing new to read,
  # unless every story is being read: linking code to a story moves its
  # updated_at, as a status move does.
  def unchanged?(story, stored)
    !@read_all && stored[story['id'].to_s] == Time.zone.parse(story['updated_at'])
  end

  def store_story(story)
    history = @shortcut.history(story['id'])
    events = ShortcutStoryHistory.new(story_id: story['id'], workflow: @workflow, history: history).events

    ApplicationRecord.transaction do
      record = @tracker.stories.find_or_initialize_by(external_id: story['id'].to_s)
      record.update!(story_attributes(story))
      record.record_events(events)
    end
  end

  # Archiving a story abandons it only while it is unfinished: teams also
  # archive finished stories to tidy their board
  def story_attributes(story)
    done = @done_states.include?(story['workflow_state_id'])
    {
      key: @tracker.story_key(story['id']),
      title: story['name'],
      url: story['app_url'],
      state: done ? 'closed' : 'open',
      state_reason: story['archived'] && !done ? 'archived' : nil,
      source_created_at: story['created_at'],
      source_updated_at: story['updated_at'],
      listed_at: @listed_at,
      gone: false
    }
  end

  # Logged by tracker and error class alone: production logs reach the
  # nightly workflow's public log, and a story's number is the workspace's
  # own. The failure named for the report keeps the story's key.
  def failure(story_id, error)
    Rails.logger.error "Story sync could not store a story of tracker #{@tracker.id}: #{error.class}"
    "#{@tracker.story_key(story_id)} (#{error.class})"
  end

  # A story the listing shows in a team the tracker does not read is gone at
  # once. One the workflow no longer lists was deleted, or moved to another
  # workflow or team; the listing reads one state at a time, and a story
  # moving between states can miss it, so it is read on its own before it is
  # marked gone. The failures to read it are returned.
  def mark_gone(stories, other_teams)
    @tracker.stories.where(gone: false, external_id: other_teams.map { |story| story['id'].to_s })
            .find_each { |story| story.update!(gone: true) }

    listed = (stories + other_teams).map { |story| story['id'].to_s }
    @tracker.stories.where(gone: false).where.not(external_id: listed).filter_map do |story|
      found = @shortcut.story(story.external_id.to_i)
      story.update!(gone: true) unless found && read?(found)
      nil
    rescue StandardError => e
      failure(story.external_id, e)
    end
  end

  def read?(story)
    story['workflow_id'].to_s == @tracker.workflow_id.to_s && @tracker.reads_team?(story['group_id'])
  end

  def report(failures, stopped)
    return if failures.empty?

    stop = stopped ? "; stopped after #{FAILURES_IN_A_ROW_LIMIT} failures in a row" : ''
    raise StoriesFailed, "Could not store stories #{failures.join(', ')}#{stop}"
  end
end
