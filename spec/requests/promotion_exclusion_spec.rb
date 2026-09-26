require 'rails_helper'

# Two repositories hold the same development pull requests; one also holds a
# promotion for every state a week reports on. Their weeks must come out
# identical, and no week page or list may show a promotion. Every cached
# num_/avg_ column is read from the schema, and every list from
# WeeksController::PR_LISTS, so a new figure or list is covered without
# touching this spec.
RSpec.describe 'Promotion pull requests never count toward a week' do
  let(:admin) { create(:user, :admin) }
  let(:week_start) { Time.zone.parse('2026-09-14 09:00') }
  let(:week_end) { Date.new(2026, 9, 20) }
  let(:plain) { create(:repository, default_branch: 'main') }
  let(:with_promotions) { create(:repository, default_branch: 'main') }

  # timeline: created (defaults to the week's start), approved, merged, closed, draft
  def pull_request(repository, title, *traits, **timeline)
    created = timeline.fetch(:created, week_start)
    pr = create(:pull_request, *traits, repository: repository, title: title, draft: timeline.fetch(:draft, false),
                                        state: timeline[:closed] ? 'closed' : 'open', gh_created_at: created,
                                        ready_for_review_at: (created unless timeline[:draft]),
                                        gh_merged_at: timeline[:merged], gh_closed_at: timeline[:closed])
    create(:review, pull_request: pr, submitted_at: timeline[:approved]) if timeline[:approved]
    pr.ensure_weeks_exist_and_update_associations
    pr
  end

  def development_work(repository)
    pull_request(repository, 'Merged feature', approved: week_start + 1.day,
                                               merged: week_start + 2.days, closed: week_start + 2.days)
    pull_request(repository, 'Abandoned feature', closed: week_start + 3.days)
    pull_request(repository, 'Waiting feature', created: week_start - 13.days, approved: week_start - 12.days)
    pull_request(repository, 'Unfinished feature', draft: true)
  end

  def promotion(repository, title, **)
    pull_request(repository, title, :promotion, **)
  end

  def promotions(repository)
    # Timings unlike the development twin's, so the averages move if it counts
    promotion(repository, 'PROMOTION merged', approved: week_start + 3.hours,
                                              merged: week_start + 6.hours, closed: week_start + 6.hours)
    promotion(repository, 'PROMOTION cancelled', closed: week_start + 3.days)
    promotion(repository, 'PROMOTION late', created: week_start - 13.days, approved: week_start - 12.days)
    promotion(repository, 'PROMOTION stale', created: week_start - 40.days, approved: week_start - 35.days)
    promotion(repository, 'PROMOTION open')
    promotion(repository, 'PROMOTION draft', draft: true)
  end

  def unflag_promotions
    PullRequest.where(promotion: true).find_each { |pull_request| pull_request.update!(promotion: false) }
  end

  def figures
    Week.column_names.grep(/\A(num|avg)_/)
  end

  def week_of(repository)
    repository.weeks.find_by!(begin_date: week_end.beginning_of_week).tap do |week|
      WeekStatsService.new(week).update_stats
    end
  end

  before do
    development_work(plain)
    development_work(with_promotions)
    promotions(with_promotions)
  end

  it 'leaves every cached weekly figure as it would be without them' do
    expect(week_of(with_promotions).slice(*figures)).to eq(week_of(plain).slice(*figures))
  end

  # Without this, a figure no fixture promotion affects would compare equal
  # either way, and its exclusion would go untested while appearing covered.
  it 'has a promotion that moves every figure, so the comparison above can fail' do
    unflag_promotions

    counted = week_of(with_promotions).slice(*figures)
    unchanged = figures.select { |figure| counted[figure] == week_of(plain)[figure] }
    expect(unchanged).to be_empty
  end

  describe 'the week page and its lists' do
    let(:week) { week_of(with_promotions) }

    before { sign_in admin }

    it 'counts only development work' do
      get repository_week_path(with_promotions, week)

      expect(response.body).to include('Open PRs: 1', 'PRs Started: 3', 'PRs With First Feedback: 1',
                                       'PRs Approved: 1', 'Late Approved PRs: 1', 'Stale Approved PRs: 0',
                                       'PRs Merged: 1', 'PRs Cancelled: 1', 'Draft PRs: 1')
    end

    WeeksController::PR_LISTS.each_key do |category|
      it "leaves promotions out of the #{category} list" do
        get pr_list_repository_week_path(with_promotions, week, category: category)

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include('PROMOTION')
      end

      it "has a promotion in the #{category} list when it counts, so the example above can fail" do
        unflag_promotions

        get pr_list_repository_week_path(with_promotions, week, category: category)

        expect(response.body).to include('PROMOTION')
      end
    end
  end
end
