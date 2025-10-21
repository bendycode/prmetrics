require 'rails_helper'

RSpec.describe 'Dashboard navigation' do
  let(:admin) { create(:user, :admin) }

  before do
    login_as(admin, scope: :user)
  end

  describe 'Total Repositories card' do
    before do
      create_list(:repository, 3)
      visit dashboard_path
    end

    it 'displays the correct number of repositories' do
      within('.card', text: 'Total Repositories') do
        expect(page).to have_content('3')
      end
    end

    it 'makes the Total Repositories card clickable' do
      # Verify the card is wrapped in a link
      expect(page).to have_css('a[href="/repositories"] .card', text: 'Total Repositories')

      # Click on the card
      click_link(href: repositories_path, match: :first)

      # Verify we're on the repositories page
      expect(page).to have_current_path(repositories_path)
      expect(page).to have_content('Repositories')
      expect(page).to have_button('Add Repository')
    end

    it 'has the card wrapped in a link with proper styling' do
      # Find the specific link containing the Total Repositories card
      card_container = find('.col-xl-3.col-md-6.mb-4', text: 'Total Repositories')

      within(card_container) do
        # Verify the link exists with proper class
        expect(page).to have_link(href: '/repositories', class: 'text-decoration-none')

        # Verify the card is inside the link
        expect(page).to have_css('a .card.shadow')
      end
    end
  end
end
