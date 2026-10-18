require 'rails_helper'

RSpec.describe ShortcutService do
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:pauses) { [] }
  let(:clock) { [0.0] }
  let(:service) do
    described_class.new('shortcut-test-token', adapter: [:test, stubs], sleep: ->(seconds) { pauses << seconds },
                                               clock: -> { clock.first })
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
      calls == 1 ? [429, { 'Retry-After' => '0' }, ''] : json_response('history_7001')
    end

    expect(service.history(7001)).not_to be_empty
    expect(calls).to be(2)
  end

  it 'raises for a response it cannot use, without the token in the message' do
    stubs.get('/api/v3/workflows/100') { [500, {}, 'Internal Server Error'] }

    expect { service.workflow(100) }.to raise_error(described_class::Error) { |error|
      expect(error.message).not_to include('shortcut-test-token')
    }
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
end
