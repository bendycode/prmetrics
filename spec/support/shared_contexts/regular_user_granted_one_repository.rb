# Signs in a regular user who was granted exactly one repository, named so a
# page that shows it can be told apart from one that shows another.
RSpec.shared_context 'with a regular user granted one repository' do
  let(:user) { create(:user) }
  let(:granted_repository) { create(:repository, name: 'granted/visible') }
  let(:week_start) { 2.weeks.ago.beginning_of_week }

  before do
    grant_access(user, granted_repository)
    sign_in user
  end
end
