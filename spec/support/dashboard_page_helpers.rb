# Reads the rendered dashboard in request specs, where there is no browser to
# ask for the page's text.
module DashboardPageHelpers
  def summary_card_value(label)
    Capybara.string(response.body).first('.card', text: label).find('.h5').text.strip
  end

  # The comma-separated values of the chart dataset with this label, as they
  # appear in the dashboard's inline chart script.
  def chart_dataset_values(label)
    response.body[/label: "#{Regexp.escape(label)}",\s*data: \[([^\]]*)\]/, 1]
  end
end

RSpec.configure do |config|
  config.include DashboardPageHelpers, type: :request
end
