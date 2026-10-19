# Shortcut payloads saved under spec/fixtures/shortcut, as the raw JSON text
# its API returns and as the parsed hashes ShortcutService hands back.
module ShortcutFixtureHelpers
  def shortcut_json(name)
    Rails.root.join("spec/fixtures/shortcut/#{name}.json").read
  end

  def shortcut_fixture(name)
    JSON.parse(shortcut_json(name))
  end
end

RSpec.configure { |config| config.include ShortcutFixtureHelpers }
