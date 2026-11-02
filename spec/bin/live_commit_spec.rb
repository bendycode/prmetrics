require 'rails_helper'
require 'open3'

# bin/live-commit runs in a subprocess against a stub heroku command placed
# first on PATH, so no example reaches Heroku.
RSpec.describe 'bin/live-commit' do
  let(:stub_dir) { Dir.mktmpdir('live-commit-stubs') }

  after { FileUtils.remove_entry(stub_dir) }

  def release(version, description, status: 'succeeded', current: false)
    { version: version, status: status, description: description, current: current }
  end

  def run_live_commit(releases_json, heroku_exit: 0)
    path = File.join(stub_dir, 'heroku')
    File.write(path, "#!/usr/bin/env bash\necho '#{releases_json}'\nexit #{heroku_exit}\n")
    File.chmod(0o755, path)
    env = { 'PATH' => "#{stub_dir}:#{ENV.fetch('PATH')}", 'HEROKU_APP' => nil }
    Open3.capture3(env, Rails.root.join('bin/live-commit').to_s, chdir: Rails.root.to_s)
  end

  it 'prints the commit of the current release when it is a deploy' do
    stdout, _stderr, status = run_live_commit([release(40, 'Deploy aaaaaaaa', current: true)].to_json)

    expect(stdout).to eq("aaaaaaaa\n")
    expect(status).to be_success
  end

  it 'prints the commit of the deploy before a config change' do
    releases = [release(40, 'Deploy aaaaaaaa'), release(41, 'Update REDIS by heroku-redis', current: true)]

    expect(run_live_commit(releases.to_json).first).to eq("aaaaaaaa\n")
  end

  it 'prints the commit a rollback restored' do
    releases = [
      release(40, 'Deploy aaaaaaaa'),
      release(41, 'Deploy bbbbbbbb'),
      release(42, 'Rollback to v40', current: true)
    ]

    expect(run_live_commit(releases.to_json).first).to eq("aaaaaaaa\n")
  end

  it 'prints nothing and exits non-zero when no release is marked current' do
    stdout, _stderr, status = run_live_commit([release(40, 'Deploy aaaaaaaa')].to_json)

    expect(stdout).to be_empty
    expect(status).not_to be_success
  end

  it 'prints nothing and exits non-zero when the releases cannot be read' do
    stdout, _stderr, status = run_live_commit('', heroku_exit: 1)

    expect(stdout).to be_empty
    expect(status).not_to be_success
  end
end
