require 'rails_helper'

RSpec.describe ReviewPolicy, type: :policy do
  it_behaves_like 'a policy limited to granted repositories' do
    let(:granted_repository) { create(:repository) }
    let(:record_in_granted) { create(:review, pull_request: create(:pull_request, repository: granted_repository)) }
    let(:record_in_ungranted) { create(:review, pull_request: create(:pull_request, repository: create(:repository))) }
  end
end
