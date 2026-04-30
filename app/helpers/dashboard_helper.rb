module DashboardHelper
  METRIC_DEFINITIONS = {
    prs_started: {
      title: 'PRs Started',
      body: 'Pull requests opened during the week (created date falls within the week).'
    },
    prs_merged: {
      title: 'PRs Merged',
      body: 'Pull requests merged during the week.'
    },
    prs_cancelled: {
      title: 'PRs Cancelled',
      body: 'Pull requests closed during the week without being merged.'
    },
    late_prs: {
      title: 'Late Approved PRs',
      body: 'Counted only for PRs that are open, non-draft, and have at least one approval. ' \
            'Within that population, this is the count whose first approval landed more than 7 ' \
            'and fewer than 28 days before the end of the week (i.e., 8-27 days approved-but-unmerged).'
    },
    stale_prs: {
      title: 'Stale Approved PRs',
      body: 'Counted only for PRs that are open, non-draft, and have at least one approval. ' \
            'Within that population, this is the count whose first approval landed 28 or more days ' \
            'before the end of the week. PRs move from Late Approved into Stale Approved at the 28-day mark.'
    },
    hours_to_first_review: {
      title: 'Hours to First Review',
      body: 'Average hours between a PR becoming ready for review and its first review. ' \
            'Time on Saturdays and Sundays is skipped entirely, but weekdays count all 24 hours -- ' \
            'there is no business-hours cap, so a PR sitting overnight Tuesday into Wednesday accrues those hours.'
    },
    hours_to_merge: {
      title: 'Hours to Merge',
      body: 'Average hours between a PR becoming ready for review and being merged. ' \
            'Time on Saturdays and Sundays is skipped entirely, but weekdays count all 24 hours -- ' \
            'there is no business-hours cap, so a PR sitting overnight Tuesday into Wednesday accrues those hours.'
    },
    merge_rate: {
      title: 'Merge Rate (%)',
      body: '(PRs merged in the last four weeks) divided by (PRs started in the last four weeks), as a percentage. ' \
            'Note: not a strict cohort ratio -- the merged set and the started set may not be the same PRs, ' \
            'since a PR can start outside the window and merge inside, or vice versa.'
    },
    total_prs_4_weeks: {
      title: 'Total PRs (4 weeks)',
      body: 'Sum of "PRs Started" across the most recent four full weeks of data for the repository.'
    },
    avg_review_time_hours: {
      title: 'Avg Review Time (hours)',
      body: 'Average of each week\'s "Hours to First Review" across the most recent four full weeks of data ' \
            'for the repository. Same underlying calculation as the Review Performance chart -- weekday hours only ' \
            '(Saturdays and Sundays skipped, weekdays count all 24 hours, no business-hours cap).'
    }
  }.freeze

  def metric_definitions(*keys)
    keys.map { |key| METRIC_DEFINITIONS.fetch(key) }
  end
end
