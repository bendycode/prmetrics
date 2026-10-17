# GitHub payloads saved under spec/fixtures/github, as an issue and its
# timeline, decoded into the resources the Octokit client returns: times are
# Time objects, and a field GitHub left out reads as nil.
module GithubFixtureHelpers
  def github_issue_fixture(name)
    github_resource(Rails.root.join("spec/fixtures/github/#{name}.json").read)
  end

  # A server error as Octokit raises it, whose message quotes the request URL
  def github_error(path)
    Octokit::ServerError.new(method: :get, url: "https://api.github.com/#{path}", status: 500, body: '',
                             response_headers: {})
  end

  def github_resource(json)
    attributes = Sawyer::Serializer.any_json.decode(json.is_a?(String) ? json : JSON.generate(json))
    Sawyer::Resource.new(Sawyer::Agent.new('https://api.github.com'), attributes)
  end
end

RSpec.configure do |config|
  config.include GithubFixtureHelpers
end
