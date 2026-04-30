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

    it 'defines a key whose title matches each Repository Performance Comparison chart label' do
      total_prs = helper.metric_definitions(:total_prs_4_weeks).first
      avg_review = helper.metric_definitions(:avg_review_time_hours).first
      merge_rate = helper.metric_definitions(:merge_rate).first

      expect(total_prs[:title]).to eq('Total PRs (4 weeks)')
      expect(avg_review[:title]).to eq('Avg Review Time (hours)')
      expect(merge_rate[:title]).to eq('Merge Rate (%)')
    end

    it 'describes merge_rate as merged-divided-by-started, not merged-divided-by-closed' do
      body = helper.metric_definitions(:merge_rate).first[:body]

      expect(body).to include('merged')
      expect(body).to include('started')
      expect(body).not_to include('closed')
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
