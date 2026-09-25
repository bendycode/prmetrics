require 'rails_helper'
require 'rake'

# Both checks compare each week's cached counts with a fresh count of its
# pull requests; the fresh count must leave promotions out, as the cached
# one does, or every repository that deploys through a pull request reports
# a discrepancy.
RSpec.describe 'Week statistics checks' do
  let(:repository) { create(:repository) }
  let(:merged_at) { Time.zone.parse('2026-09-16 10:00') }

  before do
    # rake_require loads each file once per process, however often it is called
    Rake.application.rake_require 'tasks/fix_week_stats'
    Rake.application.rake_require 'tasks/ci_checks'
    Rake::Task.define_task(:environment)

    [[], [:promotion]].each do |traits|
      create(:pull_request, *traits, repository: repository, gh_created_at: merged_at - 1.day,
                                     ready_for_review_at: merged_at - 1.day, gh_merged_at: merged_at,
                                     gh_closed_at: merged_at, state: 'closed')
        .ensure_weeks_exist_and_update_associations
    end
    repository.weeks.each { |week| WeekStatsService.new(week).update_stats }
  end

  it 'fix:check_week_discrepancies finds none for a repository with promotions' do
    Rake::Task['fix:check_week_discrepancies'].reenable

    expect { Rake::Task['fix:check_week_discrepancies'].invoke }.to output(/No discrepancies found/).to_stdout
  end

  it 'ci:data_integrity finds week statistics consistent for a repository with promotions' do
    Rake::Task['ci:data_integrity'].reenable

    expect do
      Rake::Task['ci:data_integrity'].invoke
    rescue SystemExit
      nil
    end.to output(/Week statistics look consistent/).to_stdout
  end
end
