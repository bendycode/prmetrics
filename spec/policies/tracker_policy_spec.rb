require 'rails_helper'

RSpec.describe TrackerPolicy, type: :policy do
  it_behaves_like 'a policy limited to granted repositories' do
    let(:granted_repository) { create(:repository) }
    let(:record_in_granted) { create(:tracker, :covering_source, source_repository: granted_repository) }
    let(:record_in_ungranted) { create(:tracker, :covering_source) }
  end
end
