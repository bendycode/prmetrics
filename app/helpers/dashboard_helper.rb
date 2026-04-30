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
      title: 'Late PRs',
      body: 'Open, non-draft, approved PRs whose first approval was more than 7 ' \
            'and fewer than 28 days before the end of the week (8-27 days approved-but-unmerged).'
    },
    stale_prs: {
      title: 'Stale PRs',
      body: 'Open, non-draft, approved PRs whose first approval was 28 or more days ' \
            'before the end of the week. PRs move from Late into Stale at the 28-day mark.'
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
      body: 'Percentage of PRs closed during the window that were merged (vs. cancelled).'
    },
    four_week_window: {
      title: '4-Week Window',
      body: 'Comparison values are averaged or summed across the most recent four full weeks of data.'
    }
  }.freeze

  def metric_definitions(*keys)
    keys.map { |key| METRIC_DEFINITIONS.fetch(key) }
  end
end
