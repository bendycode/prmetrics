require 'rails_helper'
require 'open3'

# bin/deploy runs in a subprocess against stub git, heroku, curl, and sleep
# commands placed first on PATH. Each stub appends its arguments to a calls
# file and answers from STUB_* variables, so no example reaches Heroku.
RSpec.describe 'bin/deploy' do
  let(:sha) { '0123456789abcdef0123456789abcdef01234567' }
  let(:stub_dir) { Dir.mktmpdir('deploy-stubs') }
  let(:calls_file) { File.join(stub_dir, 'calls.log') }

  after { FileUtils.remove_entry(stub_dir) }

  def write_stub(name, body)
    path = File.join(stub_dir, name)
    File.write(path, "#!/usr/bin/env bash\necho \"#{name} $*\" >> \"$STUB_CALLS\"\n#{body}\n")
    File.chmod(0o755, path)
  end

  def install_stubs
    write_stub('git', <<~BASH)
      case "$1" in
        rev-parse) echo "#{sha}" ;;
        branch) echo "${STUB_BRANCH:-main}" ;;
        diff-index) exit "${STUB_DIRTY:-0}" ;;
      esac
    BASH
    write_stub('heroku', <<~BASH)
      passthrough() { if [[ " $* " == *" -x "* ]]; then exit "$1"; fi; exit 0; }
      case "$*" in
        releases*) echo "${STUB_RELEASES}" ;;
        *db:migrate:status:with_data*) echo "${STUB_MIGRATE_STATUS}" ;;
        *ci:data_integrity*) code="${STUB_INTEGRITY_EXIT:-0}"; [[ " $* " == *" -x "* ]] && exit "$code"; exit 0 ;;
        ps*) echo "${STUB_PS:-web.1: up}" ;;
        info*) echo '{"app":{"web_url":"https://prmetrics.example/"}}' ;;
      esac
    BASH
    write_stub('curl', 'echo "${STUB_HEALTH:-{\"status\":\"ok\"}}"')
    write_stub('sleep', '')
  end

  def releases_json(status: 'succeeded', deployed_sha: sha)
    [{ version: 41, status: 'succeeded', description: 'Deploy aaaaaaaa' },
     { version: 42, status: status, description: "Deploy #{deployed_sha[0, 8]}" }].to_json
  end

  def migrate_status(*states)
    rows = states.map.with_index { |state, i| "   #{state}     schema  2026010100000#{i}  Migration #{i}" }
    (['', ' Status    Type    Migration ID   Migration Name', '-' * 60] + rows).join("\n")
  end

  def run_deploy(env = {})
    install_stubs
    defaults = {
      'PATH' => "#{stub_dir}:#{ENV.fetch('PATH')}",
      'STUB_CALLS' => calls_file,
      'STUB_RELEASES' => releases_json,
      'STUB_MIGRATE_STATUS' => migrate_status('up', 'up')
    }
    output, status = Open3.capture2e(defaults.merge(env), Rails.root.join('bin/deploy').to_s,
                                     chdir: Rails.root, stdin_data: '')
    [output, status]
  end

  def calls
    File.exist?(calls_file) ? File.readlines(calls_file, chomp: true) : []
  end

  def heroku_calls
    calls.select { |line| line.start_with?('heroku ') }
  end

  it 'succeeds when every check passes' do
    output, status = run_deploy

    expect(status).to be_success, output
  end

  it 'fails when the health check does not answer ok' do
    output, status = run_deploy('STUB_HEALTH' => '{"status":"error"}')

    expect(status).not_to be_success, output
  end

  it 'pushes to the app by URL, so the clone needs no heroku remote' do
    run_deploy

    expect(calls).to include('git push https://git.heroku.com/prmetrics-production.git HEAD:main')
  end

  it 'names the app on every heroku call' do
    run_deploy

    expect(heroku_calls).to all(include('-a prmetrics-production'))
  end

  it 'stops without pushing when the tree has changes and no terminal can answer' do
    output, status = run_deploy('STUB_DIRTY' => '1')

    expect(status).not_to be_success, output
    expect(output).to include('not a terminal')
    expect(calls).not_to include(a_string_starting_with('git push'))
  end

  it 'stops without pushing when the branch is not main and no terminal can answer' do
    output, status = run_deploy('STUB_BRANCH' => 'feature')

    expect(status).not_to be_success, output
    expect(output).to include('not a terminal')
    expect(calls).not_to include(a_string_starting_with('git push'))
  end

  it 'fails when the newest release is not the pushed commit' do
    output, status = run_deploy('STUB_RELEASES' => releases_json(deployed_sha: 'f' * 40))

    expect(status).not_to be_success, output
  end

  it 'accepts a config change released after the pushed commit' do
    releases = JSON.parse(releases_json) << { version: 43, status: 'succeeded',
                                              description: 'Update DATABASE by heroku-postgresql' }
    output, status = run_deploy('STUB_RELEASES' => releases.to_json)

    expect(status).to be_success, output
  end

  it 'fails when the newest release did not succeed' do
    output, status = run_deploy('STUB_RELEASES' => releases_json(status: 'failed'))

    expect(status).not_to be_success, output
  end

  it 'fails when the data integrity check fails on the dyno' do
    output, status = run_deploy('STUB_INTEGRITY_EXIT' => '1')

    expect(status).not_to be_success, output
  end

  it 'fails when a migration is still down after the release' do
    output, status = run_deploy('STUB_MIGRATE_STATUS' => migrate_status('up', 'down'))

    expect(status).not_to be_success, output
  end

  it 'leaves running migrations to the release phase' do
    run_deploy

    expect(heroku_calls.grep(/db:migrate(?!:status)/)).to be_empty
  end
end
