require 'rails_helper'
require 'open3'

# bin/post-deploy-sync-check runs in a subprocess against stub heroku and sleep
# commands placed first on PATH, so no example reaches Heroku. The stub prints
# STUB_RUN_OUTPUT for heroku run and STUB_LOGS for heroku logs.
RSpec.describe 'bin/post-deploy-sync-check' do
  let(:jid) { '4f1c2a9be07d3e5c8a6b1d20' }
  let(:stub_dir) { Dir.mktmpdir('sync-check-stubs') }
  let(:calls_file) { File.join(stub_dir, 'calls.log') }

  after { FileUtils.remove_entry(stub_dir) }

  def write_stub(name, body)
    path = File.join(stub_dir, name)
    File.write(path, "#!/usr/bin/env bash\necho \"#{name} $*\" >> \"$STUB_CALLS\"\n#{body}\n")
    File.chmod(0o755, path)
  end

  def worker_line(job_jid, message, job_class: 'UnifiedSyncJob')
    "2026-10-18T19:00:00+00:00 app[worker.1]: INFO pid=2 tid=a2a jid=#{job_jid} class=#{job_class}: #{message}"
  end

  def run_check(run_output: "post-deploy-sync-check jid=#{jid}", logs: [])
    write_stub('heroku', <<~BASH)
      case "$1" in
        run) echo "$STUB_RUN_OUTPUT" ;;
        logs) echo "$STUB_LOGS" ;;
      esac
    BASH
    write_stub('sleep', '')
    env = {
      'PATH' => "#{stub_dir}:#{ENV.fetch('PATH')}",
      'STUB_CALLS' => calls_file,
      'STUB_RUN_OUTPUT' => run_output,
      'STUB_LOGS' => logs.join("\n"),
      'SYNC_CHECK_TIMEOUT' => '30'
    }
    Open3.capture2e(env, Rails.root.join('bin/post-deploy-sync-check').to_s, chdir: Rails.root, stdin_data: '')
  end

  def heroku_calls
    File.readlines(calls_file, chomp: true).select { |line| line.start_with?('heroku ') }
  end

  it 'passes once the worker logs the enqueued job starting and finishing' do
    output, status = run_check(logs: [worker_line(jid, 'start'), worker_line(jid, 'done')])

    expect(status).to be_success, output
  end

  it 'queues the sync on the app with the remote exit status passed through' do
    run_check(logs: [worker_line(jid, 'start'), worker_line(jid, 'done')])

    expect(heroku_calls.first).to start_with('heroku run -x --no-tty -a prmetrics-production')
      .and include('UnifiedSyncJob.perform_later')
  end

  it 'reads only the worker dyno log of the app' do
    run_check(logs: [worker_line(jid, 'start'), worker_line(jid, 'done')])

    log_reads = heroku_calls.grep(/^heroku logs/)
    expect(log_reads).not_to be_empty
    expect(log_reads).to all(include('-a prmetrics-production').and(include('--dyno worker')))
  end

  it 'fails when the worker logs the enqueued job failing' do
    output, status = run_check(logs: [worker_line(jid, 'start'), worker_line(jid, 'fail')])

    expect(status).not_to be_success, output
  end

  it 'fails when the job never finishes before the timeout' do
    output, status = run_check(logs: [worker_line(jid, 'start')])

    expect(status).not_to be_success, output
  end

  it 'fails when queueing the job printed no job ID' do
    output, status = run_check(run_output: 'ActiveRecord::RecordNotFound')

    expect(status).not_to be_success, output
  end

  it 'ignores a finished sync whose job ID is not the one it queued' do
    other = '9e9e9e9e9e9e9e9e9e9e9e9e'
    output, status = run_check(logs: [worker_line(other, 'start'), worker_line(other, 'done')])

    expect(status).not_to be_success, output
  end
end
