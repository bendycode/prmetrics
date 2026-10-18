require 'rails_helper'
require 'open3'

# bin/deploy runs in a subprocess against stub git, heroku, curl, and sleep
# commands placed first on PATH. Each stub appends its arguments to a calls
# file and answers from STUB_* variables, so no example reaches Heroku. The
# git stub's push writes a marker, after which heroku releases answers with
# STUB_RELEASES_AFTER; the deploy's own post-deploy sync check runs for real
# against the same stubs.
RSpec.describe 'bin/deploy' do
  let(:sha) { '0123456789abcdef0123456789abcdef01234567' }
  let(:live_sha) { 'aaaaaaaa00000000000000000000000000000000' }
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
      case "$*" in
        "rev-parse HEAD") echo "#{sha}" ;;
        "rev-parse origin/main") echo "${STUB_ORIGIN_SHA:-#{sha}}" ;;
        "rev-parse --verify"*) [ -n "$STUB_LIVE_FULL" ] || exit 1; echo "$STUB_LIVE_FULL" ;;
        branch*) echo "${STUB_BRANCH:-main}" ;;
        diff-index*) exit "${STUB_DIRTY:-0}" ;;
        "diff --name-only"*) echo "$STUB_ADDED_FILES" ;;
        push*) touch "$STUB_DIR/pushed"; exit "${STUB_PUSH_EXIT:-0}" ;;
      esac
    BASH
    write_stub('heroku', <<~BASH)
      remote_exit() { if [[ " $* " == *" -x "* ]]; then exit "$1"; fi; exit 0; }
      case "$*" in
        releases*)
          if [ -e "$STUB_DIR/rolled-back" ]; then echo "${STUB_RELEASES_ROLLED:-$STUB_RELEASES_AFTER}"
          elif [ -e "$STUB_DIR/pushed" ]; then echo "$STUB_RELEASES_AFTER"
          else echo "$STUB_RELEASES_BEFORE"; fi ;;
        rollback*) touch "$STUB_DIR/rolled-back"; exit "${STUB_ROLLBACK_EXIT:-0}" ;;
        restart*) exit "${STUB_RESTART_EXIT:-0}" ;;
        "logs -n 100"*) exit "${STUB_LOGS_EXIT:-0}" ;;
        *db:migrate:status:with_data*) echo "$STUB_MIGRATE_STATUS"; remote_exit "${STUB_MIGRATE_EXIT:-0}" "$@" ;;
        *ci:data_integrity*) remote_exit "${STUB_INTEGRITY_EXIT:-0}" "$@" ;;
        *"rails runner"*) echo "post-deploy-sync-check jid=5c137ee5303ac4448f2532b7" ;;
        *"--dyno worker"*) echo "pid=2 tid=a2a jid=5c137ee5303ac4448f2532b7 class=UnifiedSyncJob elapsed=1.8: ${STUB_SYNC_RESULT:-done}" ;;
        ps*)
          n=$(( $(cat "$STUB_DIR/ps" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$STUB_DIR/ps"
          echo "${STUB_PS:-web.1: up}" | cut -d'|' -f"$n" ;;
        info*) if [ -z "${STUB_INFO+set}" ]; then echo '{"app":{"web_url":"https://prmetrics.example/"}}'; else echo "$STUB_INFO"; fi ;;
      esac
    BASH
    write_stub('curl', 'echo "${STUB_HEALTH:-{\"status\":\"ok\"}}"')
    write_stub('sleep', '')
  end

  def release(version, description, status: 'succeeded', current: false)
    { version: version, status: status, description: description, current: current }
  end

  # v40 deployed the live commit, and v41 changed a config var, so the code
  # serving before the deploy is v40's.
  def releases_before
    [release(40, "Deploy #{live_sha[0, 8]}"), release(41, 'Set FEATURE config vars', current: true)]
  end

  def releases_after(*newer)
    newer = [release(42, "Deploy #{sha[0, 8]}", current: true)] if newer.empty?
    releases_before.map { |r| r.merge(current: false) } + newer
  end

  def releases_rolled_back
    releases_after.map { |r| r.merge(current: false) } + [release(43, 'Rollback to v41', current: true)]
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
      'STUB_DIR' => stub_dir,
      'STUB_RELEASES_BEFORE' => releases_before.to_json,
      'STUB_RELEASES_AFTER' => releases_after.to_json,
      'STUB_RELEASES_ROLLED' => releases_rolled_back.to_json,
      'STUB_LIVE_FULL' => live_sha,
      'STUB_MIGRATE_STATUS' => migrate_status('up', 'up'),
      'SYNC_CHECK_TIMEOUT' => '30',
      'HEROKU_APP' => nil,
      'SYNC_CHECK_REPOSITORY' => nil
    }
    Open3.capture2e(defaults.merge(env), Rails.root.join('bin/deploy').to_s, chdir: Rails.root, stdin_data: '')
  end

  def calls
    File.exist?(calls_file) ? File.readlines(calls_file, chomp: true) : []
  end

  def heroku_calls
    calls.select { |line| line.start_with?('heroku ') }
  end

  def pushed?
    calls.any? { |line| line.start_with?('git push') }
  end

  def rolled_back?
    heroku_calls.any? { |line| line.start_with?('heroku rollback') }
  end

  describe 'a deploy that passes every check' do
    it 'succeeds without rolling back' do
      output, status = run_deploy

      expect(status).to be_success, output
      expect(output).to include('Deployment complete')
      expect(rolled_back?).to be(false)
    end

    it 'pushes to the app by URL, so the clone needs no heroku remote' do
      run_deploy

      expect(calls).to include('git push https://git.heroku.com/prmetrics-production.git HEAD:main')
    end

    it 'names the app on every heroku call' do
      run_deploy

      expect(heroku_calls).not_to be_empty
      expect(heroku_calls).to all(include('-a prmetrics-production'))
    end

    it 'runs a sync through the worker after the health check' do
      output, = run_deploy

      expect(output).to include('Sync check passed')
      expect(heroku_calls.index { |c| c.include?('rails runner') }).to be > heroku_calls.index { |c| c.start_with?('heroku info') }
    end

    it 'lists the commits it ships, from the commit that was serving' do
      run_deploy

      expect(calls).to include("git log --oneline --no-merges #{live_sha}..HEAD")
    end

    it 'leaves running migrations to the release phase' do
      run_deploy

      expect(heroku_calls.grep(/db:migrate(?!:status)/)).to be_empty
    end

    it 'accepts a config change released after the pushed commit' do
      after = releases_after(release(42, "Deploy #{sha[0, 8]}"), release(43, 'Update DATABASE by heroku-postgresql', current: true))
      output, status = run_deploy('STUB_RELEASES_AFTER' => after.to_json)

      expect(status).to be_success, output
    end

    it 'waits again for dynos still starting' do
      output, status = run_deploy('STUB_PS' => 'web.1: starting|web.1: up')

      expect(status).to be_success, output
      expect(heroku_calls.grep(/^heroku ps/).size).to be(2)
    end

    it 'reports a failed data integrity check without failing the deploy' do
      output, status = run_deploy('STUB_INTEGRITY_EXIT' => '1')

      expect(status).to be_success, output
      expect(output).to include('data integrity issues detected')
    end
  end

  describe 'refusing before the push' do
    it 'stops when the tree has changes and no terminal can answer' do
      output, status = run_deploy('STUB_DIRTY' => '1')

      expect(status).not_to be_success, output
      expect(output).to include('uncommitted changes', 'not a terminal')
      expect(pushed?).to be(false)
    end

    it 'stops when the branch is not main and no terminal can answer' do
      output, status = run_deploy('STUB_BRANCH' => 'feature')

      expect(status).not_to be_success, output
      expect(output).to include("instead of 'main'", 'not a terminal')
      expect(pushed?).to be(false)
    end

    it 'stops when HEAD is not origin/main and no terminal can answer' do
      output, status = run_deploy('STUB_ORIGIN_SHA' => 'b' * 40)

      expect(status).not_to be_success, output
      expect(output).to include('is not origin/main', 'not a terminal')
      expect(pushed?).to be(false)
    end

    it 'stops before pushing when no release is marked current' do
      output, status = run_deploy('STUB_RELEASES_BEFORE' => [release(40, 'Deploy aaaaaaaa')].to_json)

      expect(status).not_to be_success, output
      expect(output).to include('no release of prmetrics-production is marked current')
      expect(pushed?).to be(false)
    end
  end

  describe 'a push that leaves the pushed commit not serving' do
    it 'fails without rolling back when the release command failed' do
      after = releases_after(release(42, "Deploy #{sha[0, 8]}", status: 'failed'))
      after.find { |r| r[:version] == 41 }[:current] = true
      output, status = run_deploy('STUB_RELEASES_AFTER' => after.to_json)

      expect(status).not_to be_success, output
      expect(output).to include('release command failed', 'push a new commit')
      expect(rolled_back?).to be(false)
    end

    it 'fails without rolling back when another commit is serving' do
      output, status = run_deploy('STUB_RELEASES_AFTER' => releases_after(release(42, 'Deploy ffffffff', current: true)).to_json)

      expect(status).not_to be_success, output
      expect(output).to include('runs ffffffff, not 01234567')
      expect(rolled_back?).to be(false)
    end

    it 'names the release to roll back to when an earlier rollback took the commit off' do
      history = [release(39, "Deploy #{live_sha[0, 8]}"), release(40, "Deploy #{sha[0, 8]}"),
                 release(41, 'Rollback to v39', current: true)]
      output, status = run_deploy('STUB_RELEASES_BEFORE' => history.to_json, 'STUB_RELEASES_AFTER' => history.to_json)

      expect(status).not_to be_success, output
      expect(output).to include('made no new release', 'heroku rollback v40 -a prmetrics-production')
      expect(rolled_back?).to be(false)
    end
  end

  describe 'a push that exits non-zero' do
    it 'still checks the release and rolls back when the release went live' do
      output, status = run_deploy('STUB_PUSH_EXIT' => '1', 'STUB_HEALTH' => '{"status":"error"}')

      expect(status).not_to be_success, output
      expect(output).to include('git push exited non-zero', 'v42 serves 01234567', 'DEPLOYMENT FAILED')
      expect(rolled_back?).to be(true)
    end

    it 'fails without rolling back when no release was made' do
      output, status = run_deploy('STUB_PUSH_EXIT' => '1', 'STUB_RELEASES_AFTER' => releases_before.to_json)

      expect(status).not_to be_success, output
      expect(output).to include('DEPLOYMENT FAILED')
      expect(rolled_back?).to be(false)
    end
  end

  describe 'a check failing after the release goes live' do
    {
      'a migration is still down' => -> { { 'STUB_MIGRATE_STATUS' => migrate_status('up', 'down') } },
      'the migration status command fails on the dyno' => -> { { 'STUB_MIGRATE_EXIT' => '1' } },
      'a dyno crashed' => -> { { 'STUB_PS' => 'web.1: crashed' } },
      'a dyno crashed while starting' => -> { { 'STUB_PS' => 'web.1: starting|web.1: crashed' } },
      'the app URL is unknown' => -> { { 'STUB_INFO' => '' } },
      'the health check does not answer ok' => -> { { 'STUB_HEALTH' => '{"status":"error"}' } },
      'the restart fails' => -> { { 'STUB_RESTART_EXIT' => '1' } },
      'a dyno crashed and printing its logs fails' => -> { { 'STUB_PS' => 'web.1: crashed', 'STUB_LOGS_EXIT' => '1' } },
      'the sync check fails' => -> { { 'STUB_SYNC_RESULT' => 'fail' } }
    }.each do |failure, env|
      it "rolls back to the release that was live before when #{failure}" do
        output, status = run_deploy(instance_exec(&env))

        expect(status).not_to be_success, output
        expect(output).to include('DEPLOYMENT FAILED', 'v43 serves aaaaaaaa')
        expect(heroku_calls).to include('heroku rollback v41 -a prmetrics-production')
      end
    end

    it 'says the rollback did not take when the rolled-back release does not serve the old commit' do
      output, status = run_deploy('STUB_HEALTH' => '{"status":"error"}', 'STUB_RELEASES_ROLLED' => releases_after.to_json)

      expect(status).not_to be_success, output
      expect(output).to include('ROLLBACK DID NOT TAKE', 'v42 serves 01234567')
    end

    it 'reports which release serves after heroku rollback exits non-zero' do
      output, status = run_deploy('STUB_HEALTH' => '{"status":"error"}', 'STUB_ROLLBACK_EXIT' => '1')

      expect(status).not_to be_success, output
      expect(output).to include('heroku rollback exited non-zero', 'v43 serves aaaaaaaa')
      expect(output).not_to include('the new release is still live')
    end

    it 'says it could not confirm the rollback when the releases cannot be read afterwards' do
      output, status = run_deploy('STUB_HEALTH' => '{"status":"error"}', 'STUB_RELEASES_ROLLED' => 'not json')

      expect(status).not_to be_success, output
      expect(output).to include('Could not read the releases after the rollback')
      expect(output).not_to include('ROLLBACK DID NOT TAKE')
    end

    it 'does not roll back to the same release when the commit was already live' do
      before = [release(40, "Deploy #{sha[0, 8]}", current: true)]
      output, status = run_deploy('STUB_RELEASES_BEFORE' => before.to_json, 'STUB_RELEASES_AFTER' => before.to_json,
                                  'STUB_LIVE_FULL' => sha, 'STUB_HEALTH' => '{"status":"error"}')

      expect(status).not_to be_success, output
      expect(output).to include('Not rolling back', 'already live')
      expect(output).not_to include('To roll back by hand')
      expect(rolled_back?).to be(false)
    end

    it 'rolls back whatever ROLLBACK_BLOCKER and APP_URL the environment holds' do
      output, status = run_deploy('STUB_HEALTH' => '{"status":"error"}', 'ROLLBACK_BLOCKER' => 'from the shell',
                                  'APP_URL' => 'https://elsewhere.example')

      expect(status).not_to be_success, output
      expect(rolled_back?).to be(true)
      expect(calls.grep(/elsewhere/)).to be_empty
    end

    it 'prints the migration status output when the command fails on the dyno' do
      output, = run_deploy('STUB_MIGRATE_STATUS' => 'PG::ConnectionBad', 'STUB_MIGRATE_EXIT' => '1')

      expect(output).to include('PG::ConnectionBad', 'migration status could not be read')
    end

    it 'prints the recent logs when a dyno crashed' do
      run_deploy('STUB_PS' => 'web.1: crashed')

      expect(heroku_calls).to include('heroku logs -n 100 -a prmetrics-production')
    end

    it 'skips the health check when the app URL is unknown' do
      run_deploy('STUB_INFO' => '')

      expect(calls.grep(/^curl/)).to be_empty
    end

    it 'does not roll back over a release that adds a migration' do
      output, status = run_deploy('STUB_HEALTH' => '{"status":"error"}',
                                  'STUB_ADDED_FILES' => 'db/data/20261018000000_backfill.rb')

      expect(status).not_to be_success, output
      expect(output).to include('Not rolling back', 'db/data/20261018000000_backfill.rb',
                                'heroku rollback v41 -a prmetrics-production')
      expect(rolled_back?).to be(false)
    end

    it 'does not roll back when the live commit is not in the clone' do
      output, status = run_deploy('STUB_HEALTH' => '{"status":"error"}', 'STUB_LIVE_FULL' => '')

      expect(status).not_to be_success, output
      expect(output).to include('Not rolling back', 'aaaaaaaa is not in this clone')
      expect(rolled_back?).to be(false)
    end

    it 'checks the migrations added since the commit that was serving' do
      run_deploy

      expect(calls).to include("git diff --name-only --no-renames --diff-filter=A #{live_sha} HEAD -- db/migrate db/data")
    end
  end
end
