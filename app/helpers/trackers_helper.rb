module TrackersHelper
  # Every event kind reads as its humanized name unless it has a shorter one
  SHORTER_SOURCE_LABELS = { 'commit_referenced' => 'Commit', 'pull_request_linked' => 'Pull request' }.freeze
  STORY_SOURCE_LABELS = StoryEvent::KINDS.keys.to_h { |kind| [kind.to_s, kind.to_s.humanize] }
                                         .merge(SHORTER_SOURCE_LABELS).freeze

  def clock_label(clock)
    "#{clock.to_s.humanize} to done"
  end

  def story_source_label(source)
    STORY_SOURCE_LABELS.fetch(source.to_s)
  end

  # Rounded to the minute first: DurationFormatter rounds only the minutes,
  # so a cycle seconds short of an hour would read "23 hours, 60 minutes".
  def cycle_days(days)
    DurationFormatter.format_hours(days && ((days * 1440).round / 60.0))
  end

  # A story's URL is stored from its tracker's payload; only a URL on the
  # tracker's own site becomes a link, so a stored value can never be a
  # javascript: or other link.
  def story_title_link(story, tracker)
    return story.title unless tracker.story_url?(story.url)

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

  # For a clock none of whose finished stories has a start
  def left_out_sentence(report)
    missing = report.coverage[:missing]
    "#{pluralize(missing, "finished #{report.story_noun}")} had no start and #{missing == 1 ? 'is' : 'are'} left out."
  end

  def coverage_sentence(report)
    coverage = report.coverage
    trigger = story_source_label(report.trigger)
    sentence = "#{pluralize(coverage[:trigger], report.story_noun)} measured from #{trigger}, #{coverage[:fallback]} from a fallback."
    return sentence if coverage[:missing].zero?

    verb = coverage[:missing] == 1 ? 'had no start and is' : 'had no start and are'
    "#{sentence} #{coverage[:missing]} #{verb} left out."
  end
end
