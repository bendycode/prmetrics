require 'rails_helper'

RSpec.describe DashboardHelper do
  describe '#metric_definitions' do
    it 'returns an array with title and body for each requested key' do
      result = helper.metric_definitions(:late_prs, :stale_prs)

      expect(result).to all(have_key(:title))
      expect(result).to all(have_key(:body))
      expect(result.length).to eq(2)
    end

    it 'preserves the order of requested keys' do
      result = helper.metric_definitions(:stale_prs, :late_prs)

      expect(result.pluck(:title)).to eq(['Stale Approved PRs', 'Late Approved PRs'])
    end

    it 'leads the late PRs definition with the open/non-draft/approved filter' do
      body = helper.metric_definitions(:late_prs).first[:body]

      expect(body).to start_with('Counted only for PRs that are open, non-draft, and have at least one approval')
      expect(body).to include('more than 7 and fewer than 28 days')
    end

    it 'leads the stale PRs definition with the open/non-draft/approved filter' do
      body = helper.metric_definitions(:stale_prs).first[:body]

      expect(body).to start_with('Counted only for PRs that are open, non-draft, and have at least one approval')
      expect(body).to include('28 or more days')
    end

    it 'defines the cancelled, hours, merge rate, and four-week-window metrics' do
      keys = %i[prs_cancelled hours_to_first_review hours_to_merge merge_rate four_week_window]

      expect { helper.metric_definitions(*keys) }.not_to raise_error
    end

    it 'states explicitly which days are excluded and that weekdays have no hourly cap' do
      review_def = helper.metric_definitions(:hours_to_first_review).first
      merge_def = helper.metric_definitions(:hours_to_merge).first

      [review_def, merge_def].each do |defn|
        expect(defn[:body]).to include('Saturdays and Sundays')
        expect(defn[:body]).to include('no business-hours cap')
      end
    end

    it 'raises KeyError for unknown metric keys' do
      expect { helper.metric_definitions(:not_a_metric) }.to raise_error(KeyError)
    end
  end
end
