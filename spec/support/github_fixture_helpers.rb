# GitHub payloads saved under spec/fixtures/github, as an issue and its
# timeline. Keys are symbols, the form the Octokit client's resources take
# once converted to hashes.
module GithubFixtureHelpers
  def github_issue_fixture(name)
    JSON.parse(Rails.root.join("spec/fixtures/github/#{name}.json").read, symbolize_names: true)
  end
end

RSpec.configure do |config|
  config.include GithubFixtureHelpers
end
