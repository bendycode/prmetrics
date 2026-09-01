require 'rails_helper'

RSpec.describe 'Week page' do
  let(:admin) { create(:user, :admin) }
  let(:repository) { create(:repository, name: 'test/repo') }

  let!(:previous_week) do
    create(:week, repository: repository,
                  begin_date: Date.new(2026, 8, 24),
                  end_date: Date.new(2026, 8, 30))
  end
  let!(:week) do
    # An explicit week_number, so asserting its absence below cannot be
    # satisfied by a stray digit from the factory's sequence.
    create(:week, repository: repository,
                  week_number: 202_635,
                  begin_date: Date.new(2026, 8, 31),
                  end_date: Date.new(2026, 9, 6))
  end

  before do
    sign_in admin
  end

  it 'names the week by the dates it covers' do
    visit repository_week_path(repository, week)

    expect(page).to have_css('h1', text: "Week of 08/31/2026 for #{repository.name}")
    expect(page).to have_content('09/06/2026')
    expect(page).to have_no_content('202635')
  end

  it 'does not repeat the dates below the heading in database form' do
    visit repository_week_path(repository, week)

    expect(page).to have_css('p', text: 'Ends 09/06/2026')
    expect(page).to have_no_content('2026-08-31')
  end

  describe 'the navigation links' do
    it 'separates them from one another as buttons' do
      visit repository_week_path(repository, week)

      expect(page).to have_css('.btn-group a.btn', count: 2)
      expect(page).to have_link('Back to Repository', href: repository_path(repository),
                                                      class: 'btn')
      expect(page).to have_link('Previous Week',
                                href: repository_week_path(repository, previous_week),
                                class: 'btn')
    end
  end
end
