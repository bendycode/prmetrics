require 'rails_helper'

# The pages that list or total across repositories show a regular user only
# the repositories granted to them, and an admin every repository.
RSpec.describe 'Repository list visibility' do
  include_context 'with a regular user granted one repository'

  let(:hidden_repository) { create(:repository, name: 'hidden/secret') }
  let(:wednesday) { week_start + 2.days + 9.hours }
  let(:week_attributes) { { begin_date: week_start, end_date: week_start.end_of_week, week_number: 1 } }

  describe 'GET /repositories' do
    it 'lists granted repositories by name and no others', :aggregate_failures do
      hidden_repository
      grant_access(user, create(:repository, name: 'another/also-granted'))

      get repositories_path

      expect(response.body).to include(granted_repository.name)
      expect(response.body).not_to include(hidden_repository.name)
      expect(response.body.index('another/also-granted')).to be < response.body.index(granted_repository.name)
    end
  end

  describe 'GET /dashboard' do
    before do
      create(:week, repository: granted_repository, num_prs_started: 13, **week_attributes)
      create(:week, repository: hidden_repository, num_prs_started: 29, **week_attributes)
      create_list(:pull_request, 2, repository: granted_repository)
      create_list(:pull_request, 3, repository: hidden_repository)
    end

    it 'names only granted repositories', :aggregate_failures do
      get dashboard_path

      expect(response.body).to include(granted_repository.name)
      expect(response.body).not_to include(hidden_repository.name)
    end

    it 'counts only granted repositories and their pull requests', :aggregate_failures do
      get dashboard_path

      expect(summary_card_value('Total Repositories')).to eq('1')
      expect(summary_card_value('Total Pull Requests')).to eq('2')
    end

    it 'charts weekly totals from granted repositories only, across the user\'s repositories', :aggregate_failures do
      get dashboard_path

      expect(chart_dataset_values('PRs Started')).to eq('13')
      expect(response.body).to include('across your repositories')
    end

    it 'averages merge time over granted repositories only' do
      create(:pull_request, repository: granted_repository, ready_for_review_at: wednesday,
                            gh_merged_at: wednesday + 2.hours)
      create(:pull_request, repository: hidden_repository, ready_for_review_at: wednesday,
                            gh_merged_at: wednesday + 20.hours)

      get dashboard_path

      expect(summary_card_value('Avg Time to Merge')).to eq('2.0')
    end

    it 'averages time to first review over granted repositories only' do
      granted_pull_request = create(:pull_request, repository: granted_repository, ready_for_review_at: wednesday)
      create(:review, pull_request: granted_pull_request, submitted_at: wednesday + 3.hours)
      hidden_pull_request = create(:pull_request, repository: hidden_repository, ready_for_review_at: wednesday)
      create(:review, pull_request: hidden_pull_request, submitted_at: wednesday + 21.hours)

      get dashboard_path

      expect(summary_card_value('Avg Time to Review')).to eq('3.0')
    end

    context 'when signed in as an admin' do
      before { sign_in create(:user, :admin) }

      it 'shows every repository, its pull requests, and its weekly totals', :aggregate_failures do
        get dashboard_path

        expect(response.body).to include(hidden_repository.name)
        expect(summary_card_value('Total Pull Requests')).to eq('5')
        expect(chart_dataset_values('PRs Started')).to eq('42')
        expect(response.body).to include('across all repositories')
      end
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
