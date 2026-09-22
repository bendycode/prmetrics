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
    promotion(repository, 'PROMOTION merged', approved: week_start + 1.day,
                                              merged: week_start + 2.days, closed: week_start + 2.days)
    promotion(repository, 'PROMOTION cancelled', closed: week_start + 3.days)
    promotion(repository, 'PROMOTION late', created: week_start - 13.days, approved: week_start - 12.days)
    promotion(repository, 'PROMOTION stale', created: week_start - 40.days, approved: week_start - 35.days)
    promotion(repository, 'PROMOTION open')
    promotion(repository, 'PROMOTION draft', draft: true)
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
    figures = Week.column_names.grep(/\A(num|avg)_/)

    expect(week_of(with_promotions).slice(*figures)).to eq(week_of(plain).slice(*figures))
  end

  describe 'the week page and its lists' do
    let(:week) { week_of(with_promotions) }

    before { sign_in admin }

    it 'never lists a promotion' do
      get repository_week_path(with_promotions, week)
      expect(response.body).not_to include('PROMOTION')
    end

    WeeksController::PR_LISTS.each_key do |category|
      it "leaves promotions out of the #{category} list" do
        get pr_list_repository_week_path(with_promotions, week, category: category)

        expect(response.body).not_to include('PROMOTION')
      end
    end
  end
end
