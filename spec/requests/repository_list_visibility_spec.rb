require 'rails_helper'

# The pages that list or total across repositories show a regular user only
# the repositories granted to them, and an admin every repository.
RSpec.describe 'Repository list visibility' do
  let(:user) { create(:user) }
  let(:week_start) { 2.weeks.ago.beginning_of_week }
  let(:granted_repository) { create(:repository, name: 'granted/visible') }
  let(:hidden_repository) { create(:repository, name: 'hidden/secret') }

  before do
    grant_access(user, granted_repository)
    sign_in user
  end

  def summary_card_value(label)
    card = response.body[/#{Regexp.escape(label)}.*?font-weight-bold text-gray-800">([^<]*)</m, 1]
    card&.strip
  end

  describe 'GET /repositories' do
    it 'lists granted repositories and no others', :aggregate_failures do
      hidden_repository

      get repositories_path

      expect(response.body).to include(granted_repository.name)
      expect(response.body).not_to include(hidden_repository.name)
    end
  end

  describe 'GET /dashboard' do
    before do
      create(:week, repository: granted_repository, begin_date: week_start, end_date: week_start.end_of_week,
                    week_number: 1, num_prs_started: 13)
      create(:week, repository: hidden_repository, begin_date: week_start, end_date: week_start.end_of_week,
                    week_number: 1, num_prs_started: 29)
      create_list(:pull_request, 2, repository: granted_repository)
      create_list(:pull_request, 3, repository: hidden_repository)
    end

    it 'names only granted repositories' do
      get dashboard_path

      expect(response.body).not_to include(hidden_repository.name)
    end

    it 'counts only granted repositories and their pull requests', :aggregate_failures do
      get dashboard_path

      expect(summary_card_value('Total Repositories')).to eq('1')
      expect(summary_card_value('Total Pull Requests')).to eq('2')
    end

    it 'charts weekly totals from granted repositories only', :aggregate_failures do
      get dashboard_path

      expect(response.body).to include('data: [13]')
      expect(response.body).not_to include('data: [42]')
    end

    it 'averages merge time over granted repositories only' do
      wednesday = week_start + 2.days + 9.hours
      create(:pull_request, repository: granted_repository, ready_for_review_at: wednesday,
                            gh_merged_at: wednesday + 2.hours)
      create(:pull_request, repository: hidden_repository, ready_for_review_at: wednesday,
                            gh_merged_at: wednesday + 20.hours)

      get dashboard_path

      expect(summary_card_value('Avg Time to Merge')).to eq('2.0')
    end

    it 'averages time to first review over granted repositories only' do
      wednesday = week_start + 2.days + 9.hours
      create(:review, submitted_at: wednesday + 3.hours,
                      pull_request: create(:pull_request, repository: granted_repository,
                                                          ready_for_review_at: wednesday))
      create(:review, submitted_at: wednesday + 21.hours,
                      pull_request: create(:pull_request, repository: hidden_repository,
                                                          ready_for_review_at: wednesday))

      get dashboard_path

      expect(summary_card_value('Avg Time to Review')).to eq('3.0')
    end

    it 'shows an admin every repository', :aggregate_failures do
      sign_in create(:user, :admin)

      get dashboard_path

      expect(response.body).to include(hidden_repository.name)
      expect(summary_card_value('Total Pull Requests')).to eq('5')
    end
  end

  describe 'GET /contributors' do
    it 'lists contributors with activity in granted repositories and no others', :aggregate_failures do
      visible_author = create(:pull_request, repository: granted_repository).author
      hidden_author = create(:pull_request, repository: hidden_repository).author
      create(:contributor, username: 'no-activity')

      get contributors_path

      expect(response.body).to include(visible_author.username)
      expect(response.body).not_to include(hidden_author.username)
      expect(response.body).not_to include('no-activity')
    end
  end
end
