# Regular users see only the repositories granted to them. A spec that signs
# in a regular user and expects to see a repository grants it explicitly, so
# every spec states which repositories its user may see.
module RepositoryGrantHelpers
  def grant_access(user, *repositories)
    repositories.flatten.each do |repository|
      create(:repository_grant, user: user, repository: repository)
    end
  end
end

RSpec.configure do |config|
  config.include RepositoryGrantHelpers
end
