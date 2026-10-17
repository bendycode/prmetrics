module TrackersHelper
  CLOCK_LABELS = { 'committed' => 'Committed to done', 'started' => 'Started to done' }.freeze

  STORY_SOURCE_LABELS = {
    'opened' => 'Opened',
    'assigned' => 'Assigned',
    'commit_referenced' => 'Commit',
    'pull_request_linked' => 'Pull request',
    'closed' => 'Closed',
    'reopened' => 'Reopened'
  }.freeze

  def story_source_label(source)
    STORY_SOURCE_LABELS.fetch(source.to_s)
  end

  def cycle_days(days)
    DurationFormatter.format_hours(days && (days * 24))
  end

  # A story's URL is stored from GitHub's payload; only a GitHub URL becomes
  # a link, so a stored value can never be a javascript: or other link.
  def story_title_link(story)
    return story.title unless story.url.to_s.start_with?('https://github.com/')

    link_to story.title, story.url
  end

  def story_time(time, source = nil)
    return 'None' if time.nil?

    text = l(time.to_date, format: :us)
    source ? "#{text} (#{story_source_label(source)})" : text
  end

  # One point per finished story: when it was done, in milliseconds as
  # JavaScript counts them, and its cycle time in days.
  def cycle_time_points(report)
    report.stories.map do |story|
      { x: (story.done_at.to_f * 1000).round, y: report.days(story).round(2), key: story.key }
    end
  end

  def coverage_sentence(report)
    coverage = report.coverage
    trigger = story_source_label(report.trigger)
    sentence = "#{pluralize(coverage[:trigger], 'issue')} measured from #{trigger}, #{coverage[:fallback]} from a fallback."
    return sentence if coverage[:missing].zero?

    verb = coverage[:missing] == 1 ? 'had no start and is' : 'had no start and are'
    "#{sentence} #{coverage[:missing]} #{verb} left out."
  end
end
