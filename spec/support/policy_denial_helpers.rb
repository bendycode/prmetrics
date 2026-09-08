# The read policies permit every signed-in user, so they have no denying
# input. A spec that needs a denial stubs the policy for one exact user and
# record; the .with constraint makes a lookup for any other record fail
# loudly instead of passing by accident.
module PolicyDenialHelpers
  def deny_policy(policy_class, query, user, on:)
    denying_policy = instance_double(policy_class, { query => false })
    allow(policy_class).to receive(:new).with(user, on).and_return(denying_policy)
  end
end

RSpec.configure do |config|
  config.include PolicyDenialHelpers
end
