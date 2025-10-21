require 'rails_helper'

RSpec.describe 'Favicon' do
  describe 'favicon links in HTML head' do
    it 'includes all favicon variants on the main application' do
      visit root_path

      # Check for standard favicon
      expect(page).to have_css('link[rel="icon"][type="image/x-icon"][href="/favicon.ico"]', visible: :hidden)

      # Check for PNG favicons
      expect(page).to have_css('link[rel="icon"][type="image/png"][sizes="32x32"][href="/favicon-32x32.png"]', visible: :hidden)
      expect(page).to have_css('link[rel="icon"][type="image/png"][sizes="16x16"][href="/favicon-16x16.png"]', visible: :hidden)

      # Check for Apple touch icon
      expect(page).to have_css('link[rel="apple-touch-icon"][sizes="180x180"][href="/apple-touch-icon.png"]', visible: :hidden)

      # Check for manifest
      expect(page).to have_css('link[rel="manifest"][href="/site.webmanifest"]', visible: :hidden)

      # Check for theme color
      expect(page).to have_css('meta[name="theme-color"][content="#3b82f6"]', visible: :hidden)
    end

    it 'includes all favicon variants on the admin pages' do
      admin = create(:user, :admin)
      sign_in admin
      visit users_path

      # Check for standard favicon
      expect(page).to have_css('link[rel="icon"][type="image/x-icon"][href="/favicon.ico"]', visible: :hidden)

      # Check for PNG favicons
      expect(page).to have_css('link[rel="icon"][type="image/png"][sizes="32x32"][href="/favicon-32x32.png"]', visible: :hidden)
      expect(page).to have_css('link[rel="icon"][type="image/png"][sizes="16x16"][href="/favicon-16x16.png"]', visible: :hidden)

      # Check for Apple touch icon
      expect(page).to have_css('link[rel="apple-touch-icon"][sizes="180x180"][href="/apple-touch-icon.png"]', visible: :hidden)

      # Check for manifest
      expect(page).to have_css('link[rel="manifest"][href="/site.webmanifest"]', visible: :hidden)

      # Check for theme color
      expect(page).to have_css('meta[name="theme-color"][content="#3b82f6"]', visible: :hidden)
    end
  end

  describe 'favicon files existence' do
    it 'serves favicon files correctly' do
      # Test that favicon files return 200 status
      visit '/favicon.ico'
      expect(page.status_code).to eq(200)

      visit '/favicon-16x16.png'
      expect(page.status_code).to eq(200)

      visit '/favicon-32x32.png'
      expect(page.status_code).to eq(200)

      visit '/apple-touch-icon.png'
      expect(page.status_code).to eq(200)

      visit '/site.webmanifest'
      expect(page.status_code).to eq(200)
    end
  end

  describe 'web manifest content' do
    it 'contains correct app information' do
      visit '/site.webmanifest'

      manifest = JSON.parse(page.body)

      expect(manifest['name']).to eq('prmetrics.io')
      expect(manifest['short_name']).to eq('prmetrics')
      expect(manifest['theme_color']).to eq('#3b82f6')
      expect(manifest['background_color']).to eq('#ffffff')
      expect(manifest['display']).to eq('standalone')

      # Check icons
      expect(manifest['icons']).to be_an(Array)
      expect(manifest['icons'].length).to eq(2)

      icon_192 = manifest['icons'].find { |i| i['sizes'] == '192x192' }
      expect(icon_192['src']).to eq('/android-chrome-192x192.png')
      expect(icon_192['type']).to eq('image/png')

      icon_512 = manifest['icons'].find { |i| i['sizes'] == '512x512' }
      expect(icon_512['src']).to eq('/android-chrome-512x512.png')
      expect(icon_512['type']).to eq('image/png')
    end
  end
end