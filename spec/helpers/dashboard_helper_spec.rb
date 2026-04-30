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

      expect(result.pluck(:title)).to eq(['Stale PRs', 'Late PRs'])
    end

    it 'states the 7-day threshold for late PRs' do
      definition = helper.metric_definitions(:late_prs).first

      expect(definition[:body]).to include('7')
      expect(definition[:body]).to include('28')
    end

    it 'states the 28-day threshold for stale PRs' do
      definition = helper.metric_definitions(:stale_prs).first

      expect(definition[:body]).to include('28')
    end

    it 'defines the cancelled, hours, merge rate, and four-week-window metrics' do
      keys = %i[prs_cancelled hours_to_first_review hours_to_merge merge_rate four_week_window]

      expect { helper.metric_definitions(*keys) }.not_to raise_error
    end

    it 'raises KeyError for unknown metric keys' do
      expect { helper.metric_definitions(:not_a_metric) }.to raise_error(KeyError)
    end
  end
end
