require 'rails_helper'

RSpec.describe PullRequestUserPolicy, type: :policy do
  let(:granted_repository) { create(:repository) }
  let(:record_in_granted) { create(:pull_request_user, pull_request: create(:pull_request, repository: granted_repository)) }
  let(:record_in_ungranted) { create(:pull_request_user, pull_request: create(:pull_request, repository: create(:repository))) }

  it_behaves_like 'a policy limited to granted repositories'
end
