require 'rails_helper'

RSpec.describe 'Dashboard averages' do
  let(:repository) { create(:repository) }
  let(:wednesday) { 2.weeks.ago.beginning_of_week + 2.days + 9.hours }

  before { sign_in create(:user, :admin) }

  def summary_card_value(label)
    Capybara.string(response.body).first('.card', text: label).find('.h5').text.strip
  end

  it 'averages time to merge over merged pull requests only' do
    create(:pull_request, repository: repository, ready_for_review_at: wednesday, gh_merged_at: wednesday + 4.hours)
    create(:pull_request, repository: repository, ready_for_review_at: wednesday, gh_merged_at: nil)

    get dashboard_path

    expect(summary_card_value('Avg Time to Merge')).to eq('4.0')
  end
end
