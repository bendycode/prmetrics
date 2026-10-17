require 'rails_helper'

RSpec.describe 'Cycle Time link on a repository page' do
  let(:user) { create(:user) }
  let(:repository) { create(:repository) }

  before do
    grant_access(user, repository)
    sign_in user
  end

  it 'leads from a tracked repository to its Cycle Time page' do
    tracker = create(:tracker, :covering_source, source_repository: repository)

    visit repository_path(repository)
    click_link 'Cycle Time'

    expect(page).to have_current_path(tracker_path(tracker))
  end

  it 'is absent from a repository whose issues are not tracked' do
    visit repository_path(repository)

    expect(page).to have_css('h1', text: repository.name)
    expect(page).to have_no_link('Cycle Time')
  end
end
