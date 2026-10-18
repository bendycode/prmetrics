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
    listed_at = Time.current
    workflow = @shortcut.workflow(@tracker.workflow_id)
    done_states = workflow['states'].select { |state| state['type'] == 'done' }.pluck('id')
    stories = workflow['states'].flat_map { |state| @shortcut.stories_in_state(state['id']) }

    failures, stopped = store_changed(stories, workflow, done_states, listed_at)
    mark_gone(stories) unless stopped
    measure_stories
    report(failures, stopped)
  end

  private

  # Everything about a story is read from Shortcut before it is written, and
  # written in one transaction, since a story stored at its current update
  # is not read again.
  def store_changed(stories, workflow, done_states, listed_at)
    stored = stored_updates(stories)
    failures = []
    in_a_row = 0
    stories.each do |story|
      next if !@full && stored[story['id'].to_s] == Time.zone.parse(story['updated_at'])

      store_story(story, workflow, done_states, listed_at)
      in_a_row = 0
    rescue StandardError => e
      # The class alone: production logs reach the nightly workflow's log,
      # which is public
      key = @tracker.story_key(story['id'])
      Rails.logger.error "Story sync could not store story #{key}: #{e.class}"
      failures << "#{key} (#{e.class})"
      in_a_row += 1
      return [failures, true] if in_a_row >= FAILURES_IN_A_ROW_LIMIT
    end
    [failures, false]
  end

  def store_story(story, workflow, done_states, listed_at)
    history = @shortcut.history(story['id'])
    events = ShortcutStoryHistory.new(story_id: story['id'], workflow: workflow, history: history).events

    ApplicationRecord.transaction do
      record = @tracker.stories.find_or_initialize_by(external_id: story['id'].to_s)
      record.update!(story_attributes(story, done_states, listed_at))
      record.record_events(events)
    end
  end

  def story_attributes(story, done_states, listed_at)
    {
      key: @tracker.story_key(story['id']),
      title: story['name'],
      url: story['app_url'],
      state: done_states.include?(story['workflow_state_id']) ? 'closed' : 'open',
      state_reason: story['archived'] ? 'archived' : nil,
      source_created_at: story['created_at'],
      source_updated_at: story['updated_at'],
      listed_at: listed_at,
      gone: false
    }
  end

  # The update each listed story is stored at, for stories listed after it
  def stored_updates(stories)
    @tracker.stories.where(external_id: stories.map { |story| story['id'].to_s }, gone: false)
            .listed_after_last_update
            .pluck(:external_id, :source_updated_at).to_h
  end

  # A story the workflow no longer lists was deleted, or moved to another
  # workflow. The listing reads one state at a time, and a story moving
  # between states can miss it, so a missing story is read on its own before
  # it is marked gone.
  def mark_gone(stories)
    listed = stories.map { |story| story['id'].to_s }
    @tracker.stories.where(gone: false).where.not(external_id: listed).find_each do |story|
      found = @shortcut.story(story.external_id.to_i)
      story.update!(gone: true) if found.nil? || found['workflow_id'].to_s != @tracker.workflow_id.to_s
    end
  end

  def measure_stories
    @tracker.stories.includes(:events).find_each do |story|
      story.measure(@tracker.triggers)
    end
  end

  def report(failures, stopped)
    return if failures.empty?

    stop = stopped ? "; stopped after #{FAILURES_IN_A_ROW_LIMIT} failures in a row" : ''
    raise StoriesFailed, "Could not store stories #{failures.join(', ')}#{stop}"
  end
end
