require 'rails_helper'
require 'open3'

# bin/post-deploy-sync-check runs in a subprocess against stub heroku and sleep
# commands placed first on PATH, so no example reaches Heroku. Each heroku run
# call queues job number N, whose ID is job_id(N); STUB_RESULTS lists, per job,
# what the worker log shows for it: done, fail, or start (still running).
RSpec.describe 'bin/post-deploy-sync-check' do
  let(:stub_dir) { Dir.mktmpdir('sync-check-stubs') }
  let(:calls_file) { File.join(stub_dir, 'calls.log') }

  after { FileUtils.remove_entry(stub_dir) }

  def job_id(number)
    "4f1c2a9be07d3e5c8a6b1d2#{number}"
  end

  def write_stub(name, body)
    path = File.join(stub_dir, name)
    File.write(path, "#!/usr/bin/env bash\necho \"#{name} $*\" >> \"$STUB_CALLS\"\n#{body}\n")
    File.chmod(0o755, path)
  end

  def install_stubs
    write_stub('heroku', <<~BASH)
      counter="$STUB_DIR/queued"
      case "$1" in
        run)
          n=$(( $(cat "$counter" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$counter"
          [ -n "$STUB_RUN_OUTPUT" ] && { echo "$STUB_RUN_OUTPUT"; exit "${STUB_RUN_EXIT:-0}"; }
          echo "post-deploy-sync-check jid=4f1c2a9be07d3e5c8a6b1d2$n" ;;
        logs)
          echo "#{worker_line('9e9e9e9e9e9e9e9e9e9e9e9e', 'done')}"
          [ -n "$STUB_EXTRA_LOG" ] && echo "$STUB_EXTRA_LOG"
          n=$(cat "$counter" 2>/dev/null || echo 0); i=1
          for result in $STUB_RESULTS; do
            if [ "$i" -le "$n" ]; then
              jid="4f1c2a9be07d3e5c8a6b1d2$i"
              echo "pid=2 tid=a2a jid=$jid class=UnifiedSyncJob: start"
              [ "$result" = start ] || echo "pid=2 tid=a2a jid=$jid class=UnifiedSyncJob elapsed=2.9: $result"
            fi
            i=$((i + 1))
          done
          exit "${STUB_LOGS_EXIT:-0}" ;;
      esac
    BASH
    write_stub('sleep', '')
  end

  def worker_line(job_jid, message)
    "2026-10-18T19:00:00+00:00 app[worker.1]: INFO pid=2 tid=a2a jid=#{job_jid} class=UnifiedSyncJob elapsed=2.9: #{message}"
  end

  def run_check(results:, env: {})
    install_stubs
    defaults = {
      'PATH' => "#{stub_dir}:#{ENV.fetch('PATH')}",
      'STUB_CALLS' => calls_file,
      'STUB_DIR' => stub_dir,
      'STUB_RESULTS' => results.join(' '),
      'SYNC_CHECK_TIMEOUT' => '30',
      'HEROKU_APP' => nil,
      'SYNC_CHECK_REPOSITORY' => nil
    }
    Open3.capture2e(defaults.merge(env), Rails.root.join('bin/post-deploy-sync-check').to_s,
                    chdir: Rails.root, stdin_data: '')
  end

  def heroku_calls
    File.readlines(calls_file, chomp: true).select { |line| line.start_with?('heroku ') }
  end

  def queue_calls
    heroku_calls.grep(/^heroku run/)
  end

  it 'passes once the worker logs the queued job finishing' do
    output, status = run_check(results: %w[done])

    expect(status).to be_success, output
    expect(output).to include("Job ID: #{job_id(1)}", 'Sync check passed')
    expect(queue_calls.size).to be(1)
  end

  it 'queues the sync for the repository on the app, passing the name as an environment variable' do
    run_check(results: %w[done])

    expect(queue_calls.first).to start_with('heroku run -x --no-tty -a prmetrics-production')
      .and include('--env SYNC_CHECK_REPOSITORY=bendycode/prmetrics')
      .and include("ENV.fetch('SYNC_CHECK_REPOSITORY')")
    expect(queue_calls.first).not_to include("name: 'bendycode/prmetrics'")
  end

  it 'reads only the worker dyno log of the app' do
    run_check(results: %w[done])

    log_reads = heroku_calls.grep(/^heroku logs/)
    expect(log_reads).not_to be_empty
    expect(log_reads).to all(include('-a prmetrics-production').and(include('--dyno worker')))
  end

  it 'passes when a second attempt finishes after the first job fails' do
    output, status = run_check(results: %w[fail done])

    expect(status).to be_success, output
    expect(output).to include("job #{job_id(1)} failing", 'Trying once more')
    expect(queue_calls.size).to be(2)
  end

  it 'fails when the job fails on both attempts' do
    output, status = run_check(results: %w[fail fail])

    expect(status).not_to be_success, output
    expect(output).to include('SYNC CHECK FAILED after 2 attempt(s)')
  end

  it 'fails when the job never finishes before the timeout' do
    output, status = run_check(results: %w[start start])

    expect(status).not_to be_success, output
    expect(output).to include("No done line for job #{job_id(2)} within 30s")
  end

  it 'fails when queueing the job prints no job ID' do
    output, status = run_check(results: [], env: { 'STUB_RUN_OUTPUT' => 'Running rails runner on prmetrics-production' })

    expect(status).not_to be_success, output
    expect(output).to include('printed no job ID')
  end

  it 'fails when queueing the job fails on the dyno' do
    output, status = run_check(results: [], env: { 'STUB_RUN_OUTPUT' => 'ActiveRecord::RecordNotFound',
                                                   'STUB_RUN_EXIT' => '1' })

    expect(status).not_to be_success, output
    expect(output).to include('ActiveRecord::RecordNotFound', 'Queueing the job failed on the dyno')
  end

  it 'gives up without a second sync after three failed reads of the worker log' do
    output, status = run_check(results: %w[start start], env: { 'STUB_LOGS_EXIT' => '1', 'SYNC_CHECK_TIMEOUT' => '300' })

    expect(status).not_to be_success, output
    expect(output.scan('heroku logs failed').size).to be(3)
    expect(output).to include('could not read the worker log')
    expect(queue_calls.size).to be(1)
  end

  it 'ignores a finished job whose ID only starts with the queued one' do
    longer = "#{job_id(1)}ff"
    output, status = run_check(results: [], env: { 'STUB_RUN_OUTPUT' => "post-deploy-sync-check jid=#{job_id(1)}",
                                                   'STUB_EXTRA_LOG' => worker_line(longer, 'done') })

    expect(status).not_to be_success, output
  end

  it 'ignores a finished sync whose job ID is not the one it queued' do
    output, status = run_check(results: %w[start start])

    expect(status).not_to be_success, output
    expect(output).not_to include('9e9e9e9e9e9e9e9e9e9e9e9e')
  end
end
