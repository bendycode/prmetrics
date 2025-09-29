require 'rails_helper'

RSpec.describe 'Branding', type: :system do
  describe 'Logo display' do
    context 'when logged in' do
      let(:admin) { create(:user, :admin) }

      before do
        login_as(admin, scope: :user)
      end
      
      it 'displays the logo in the sidebar' do
        visit dashboard_path
        
        within('.sidebar') do
          # Check that the logo image is present
          expect(page).to have_css('img[alt="prmetrics.io"]')
          
          # Verify it's using the correct image file
          logo = find('img[alt="prmetrics.io"]')
          expect(logo['src']).to match(/prmetrics_logo.*\.svg/)
          
          # Verify the logo is wrapped in a link to the homepage
          expect(page).to have_link(href: '/')
          
          # Check that the white background container exists
          expect(page).to have_css('.sidebar-brand-icon[style*="background-color: white"]')
        end
      end
    end
    
    context 'on the login page' do
      it 'displays the logo above the login form' do
        visit new_user_session_path
        
        # Check that the logo is present on the login page
        expect(page).to have_css('img[alt="prmetrics.io"]')
        
        # Verify it's in the login card
        within('.card') do
          logo = find('img[alt="prmetrics.io"]')
          expect(logo['src']).to match(/prmetrics_logo.*\.svg/)
        end
      end
    end
  end
end