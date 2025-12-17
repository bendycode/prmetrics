require 'rails_helper'

RSpec.describe 'Dashboard Chart Preferences', :js do
  let(:user) { create(:user) }
  let(:repository) { create(:repository, name: 'test/repo') }

  before do
    # Create test data with metrics
    create(:week,
           repository: repository,
           num_prs_started: 10,
           num_prs_merged: 8,
           num_prs_cancelled: 2,
           num_prs_late: 3,
           num_prs_stale: 1)

    sign_in user
    visit dashboard_path
  end

  def wait_for_charts
    # Wait for charts to render
    expect(page).to have_css('#prVelocityChart')
    sleep 1 # Allow Chart.js initialization
  end

  it 'persists PR Velocity chart visibility across page refreshes' do
    wait_for_charts

    # Verify ChartPreferences utility exists
    chart_prefs_exists = page.evaluate_script('typeof ChartPreferences !== "undefined"')
    expect(chart_prefs_exists).to be true

    # Verify chart is exposed globally
    chart_exists = page.evaluate_script('typeof window.prVelocityChart !== "undefined"')
    expect(chart_exists).to be true

    # Hide "PRs Cancelled" dataset by clicking legend
    page.evaluate_script('window.prVelocityChart.options.plugins.legend.onClick(null, {datasetIndex: 2});')

    # Verify localStorage was updated
    prefs = page.evaluate_script('JSON.parse(localStorage.getItem("prmetrics_chart_preferences"))')
    expect(prefs).not_to be_nil
    expect(prefs['prVelocityChart']).not_to include('PRs Cancelled')
    expect(prefs['prVelocityChart']).to include('PRs Started', 'PRs Merged')

    # Hard refresh page
    visit dashboard_path
    wait_for_charts

    # Verify dataset still hidden after refresh
    hidden = page.evaluate_script('window.prVelocityChart.getDatasetMeta(2).hidden')
    expect(hidden).to be true
  end

  it 'stores preferences independently for each chart' do
    wait_for_charts

    # Hide dataset in PR Velocity chart
    page.evaluate_script('window.prVelocityChart.options.plugins.legend.onClick(null, {datasetIndex: 0});')

    # Verify localStorage contains only prVelocityChart preferences
    prefs = page.evaluate_script('JSON.parse(localStorage.getItem("prmetrics_chart_preferences"))')
    expect(prefs.keys).to include('prVelocityChart')
    expect(prefs['reviewPerformanceChart']).to be_nil
    expect(prefs['repositoryComparisonChart']).to be_nil
  end

  it 'handles missing localStorage gracefully' do
    wait_for_charts

    # Clear localStorage
    page.evaluate_script('localStorage.clear()')

    # Refresh page
    visit dashboard_path
    wait_for_charts

    # Verify charts render with all datasets visible (default)
    visible_count = page.evaluate_script(
      'window.prVelocityChart.data.datasets.filter(function(d, i) { ' \
      'return !window.prVelocityChart.getDatasetMeta(i).hidden; }).length'
    )
    expect(visible_count).to eq(5)
  end

  it 'restores default state when localStorage has invalid JSON' do
    # Corrupt localStorage before visiting page
    page.execute_script('localStorage.setItem("prmetrics_chart_preferences", "invalid json")')

    # Visit page - should not crash
    visit dashboard_path
    wait_for_charts

    # Verify all datasets are visible (default state)
    visible_count = page.evaluate_script(
      'window.prVelocityChart.data.datasets.filter(function(d, i) { ' \
      'return !window.prVelocityChart.getDatasetMeta(i).hidden; }).length'
    )
    expect(visible_count).to eq(5)
  end
end
