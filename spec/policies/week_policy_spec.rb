require 'rails_helper'

RSpec.describe WeekPolicy, type: :policy do
  let(:granted_repository) { create(:repository) }
  let(:record_in_granted) { create(:week, repository: granted_repository) }
  let(:record_in_ungranted) { create(:week, repository: create(:repository)) }

  it_behaves_like 'a policy limited to granted repositories'
end
