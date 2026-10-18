require 'rails_helper'

RSpec.describe ShortcutService do
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:pauses) { [] }
  let(:clock) { [0.0] }
  let(:service) do
    described_class.new('shortcut-test-token', adapter: [:test, stubs], sleep: ->(seconds) { pauses << seconds },
                                               clock: -> { clock.first }, retry_interval: 0)
  end

  def json_response(name, status = 200)
    [status, { 'Content-Type' => 'application/json' }, shortcut_json(name)]
  end

  after { stubs.verify_stubbed_calls }

  it 'reads a workflow' do
    stubs.get('/api/v3/workflows/100') { json_response('workflow') }

    expect(service.workflow(100)).to include('id' => 100, 'default_state_id' => 101)
  end

  it 'lists the stories in a workflow state, archived ones included' do
    stubs.post('/api/v3/stories/search', { workflow_state_id: 105 }.to_json) { json_response('search_state_105', 201) }

    expect(service.stories_in_state(105).pluck('id', 'archived')).to eq([[7001, false], [7002, true]])
  end

  it 'reads a story\'s history' do
    stubs.get('/api/v3/stories/7001/history') { json_response('history_7001') }

    expect(service.history(7001).first).to include('id' => 'h-1', 'changed_at' => '2026-09-01T15:00:00Z')
  end

  it 'reads a story' do
    stubs.get('/api/v3/stories/7001') { json_response('story_7001') }

    expect(service.story(7001)).to include('id' => 7001, 'workflow_id' => 100)
  end

  it 'raises its own not-found error for a history Shortcut no longer has' do
    stubs.get('/api/v3/stories/7009/history') { json_response('not_found', 404) }

    expect { service.history(7009) }.to raise_error(described_class::NotFound, %r{404 to GET stories/7009/history})
  end

  it 'answers nil for a story Shortcut no longer has' do
    stubs.get('/api/v3/stories/7009') { json_response('not_found', 404) }

    expect(service.story(7009)).to be_nil
  end

  it 'sends the token in Shortcut\'s header' do
    stubs.get('/api/v3/workflows/100') do |env|
      expect(env.request_headers['Shortcut-Token']).to eq('shortcut-test-token')
      json_response('workflow')
    end

    service.workflow(100)
  end

  it 'waits out a rate limit and tries again' do
    calls = 0
    stubs.get('/api/v3/stories/7001/history') do
      calls += 1
      calls == 1 ? [429, {}, ''] : json_response('history_7001')
    end

    expect(service.history(7001)).not_to be_empty
    expect(calls).to be(2)
  end

  it 'tries again after a server error' do
    calls = 0
    stubs.get('/api/v3/workflows/100') do
      calls += 1
      calls == 1 ? [503, {}, ''] : json_response('workflow')
    end

    expect(service.workflow(100)).to include('id' => 100)
  end

  it 'waits out a rate limit whose reset is given as a timestamp moments away' do
    calls = 0
    stubs.get('/api/v3/workflows/100') do
      calls += 1
      calls == 1 ? [429, { 'RateLimit-Reset' => Time.now.to_i.to_s }, ''] : json_response('workflow')
    end

    expect(service.workflow(100)).to include('id' => 100)
  end

  it 'gives up on a rate limit that asks for a wait longer than two minutes' do
    stubs.get('/api/v3/workflows/100') { [429, { 'Retry-After' => '600' }, ''] }

    expect { service.workflow(100) }.to raise_error(described_class::Error, /429/)
  end

  # An error is inspected in consoles and error reports, and a cause comes along
  it 'raises for a response it cannot use, naming the request, with the token nowhere in the error' do
    stubs.get('/api/v3/workflows/100') { [500, {}, 'Internal Server Error'] }

    expect { service.workflow(100) }.to raise_error(described_class::Error) { |error|
      expect(error.message).to match(%r{500 to GET workflows/100})
      expect(error.cause).to be_nil
      expect([error.inspect, error.full_message]).to all(exclude('shortcut-test-token'))
    }
  end

  it 'keeps its token out of its own inspect' do
    expect(service.inspect).not_to include('shortcut-test-token')
  end

  it 'tries again when the connection fails, then reports that nothing answered' do
    calls = 0
    stubs.get('/api/v3/workflows/100') do
      calls += 1
      raise Faraday::ConnectionFailed, 'connection refused'
    end

    expect { service.workflow(100) }.to raise_error(described_class::Error, %r{nothing to GET workflows/100})
    expect(calls).to be > 1
  end

  it 'waits out a rate limit on a story search and tries again' do
    calls = 0
    stubs.post('/api/v3/stories/search') do
      calls += 1
      calls == 1 ? [429, {}, ''] : json_response('search_state_105', 201)
    end

    expect(service.stories_in_state(105)).not_to be_empty
    expect(calls).to be(2)
  end

  # Shortcut allows 200 requests a minute
  it 'spaces its requests at least 0.3 seconds apart' do
    stubs.get('/api/v3/stories/7001') { json_response('story_7001') }
    stubs.get('/api/v3/stories/7001') { json_response('story_7001') }

    service.story(7001)
    clock[0] = 0.1
    service.story(7001)

    expect(pauses).to contain_exactly(be_within(0.001).of(0.2))
  end

  it 'does not pause when the last request was long enough ago' do
    stubs.get('/api/v3/stories/7001') { json_response('story_7001') }
    stubs.get('/api/v3/stories/7001') { json_response('story_7001') }

    service.story(7001)
    clock[0] = 0.5
    service.story(7001)

    expect(pauses).to be_empty
  end
end
