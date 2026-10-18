require 'faraday/retry'

# Reads a Shortcut workspace through its v3 REST API with one tracker's token.
class ShortcutService
  BASE_URL = 'https://api.app.shortcut.com/api/v3/'.freeze
  # Shortcut allows 200 requests a minute for each token
  MINIMUM_INTERVAL = 60.0 / 200

  # Raised for any response the service cannot use. The message names the
  # request and its status, never the token, which travels in a header.
  class Error < StandardError; end

  def initialize(token, adapter: Faraday.default_adapter, sleep: Kernel.method(:sleep),
                 clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
    @sleep = sleep
    @clock = clock
    @connection = Faraday.new(url: BASE_URL, headers: { 'Shortcut-Token' => token }) do |faraday|
      # Outermost, so it raises only for the response the retries end on
      faraday.response :raise_error
      faraday.request :json
      # Story search is a POST that only reads, so it is retried like a GET
      faraday.request :retry, max: 5, interval: 1, backoff_factor: 2, retry_statuses: [429], methods: %i[get post]
      faraday.response :json
      faraday.adapter(*Array(adapter))
    end
  end

  def workflow(id)
    request(:get, "workflows/#{id}")
  end

  # Every story in a workflow state, archived ones included
  def stories_in_state(state_id)
    request(:post, 'stories/search', workflow_state_id: state_id)
  end

  # A story, or nil once Shortcut no longer has it
  def story(id)
    request(:get, "stories/#{id}")
  rescue Faraday::ResourceNotFound
    nil
  end

  def history(story_id)
    request(:get, "stories/#{story_id}/history")
  end

  private

  def request(method, path, body = nil)
    pace
    @connection.public_send(method, path, body).body
  rescue Faraday::ResourceNotFound
    raise
  rescue Faraday::Error => e
    raise Error, "Shortcut answered #{e.response_status || 'nothing'} to #{method.upcase} #{path}"
  end

  def pace
    now = @clock.call
    @sleep.call(MINIMUM_INTERVAL - (now - @last_request_at)) if @last_request_at && now - @last_request_at < MINIMUM_INTERVAL
    @last_request_at = @clock.call
  end
end
