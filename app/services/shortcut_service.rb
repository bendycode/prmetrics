require 'faraday/retry'

# Reads a Shortcut workspace through its v3 REST API with one tracker's token.
class ShortcutService
  BASE_URL = 'https://api.app.shortcut.com/api/v3/'.freeze
  # Shortcut allows 200 requests a minute for each token
  MINIMUM_INTERVAL = 60.0 / 200
  # Doubling from the interval, the waits add up to over two minutes, past
  # the minute a rate limit counts over
  RETRIES = 7
  # A response asking for a longer wait than this is answered as it came
  # instead of slept on
  LONGEST_WAIT = 120
  # A wait header holding a number past this is a Unix timestamp, not seconds
  TIMESTAMP_FLOOR = 1_000_000_000
  # Every request only reads, so a server's passing failure is retried too
  RETRY_STATUSES = [429, 500, 502, 503, 504].freeze

  # Raised for any response the service cannot use. It names the request and
  # its status, never the token, and carries no cause: Faraday's errors can
  # hold the request's headers, the token among them.
  class Error < StandardError; end
  class NotFound < Error; end

  def initialize(token, adapter: Faraday.default_adapter, sleep: Kernel.method(:sleep),
                 clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }, retry_interval: 1)
    @sleep = sleep
    @clock = clock
    @connection = connection(token, adapter, retry_interval)
  end

  def workflow(id)
    request(:get, "workflows/#{id}")
  end

  # Every story in a workflow state, archived ones included
  def stories_in_state(state_id)
    request(:post, 'stories/search', { workflow_state_id: state_id })
  end

  # A story, or nil once Shortcut no longer has it
  def story(id)
    request(:get, "stories/#{id}")
  rescue NotFound
    nil
  end

  def history(story_id)
    request(:get, "stories/#{story_id}/history")
  end

  def inspect
    "#<#{self.class.name}>"
  end

  # Seconds to wait for a Retry-After or RateLimit-Reset value, which can be
  # a count of seconds, an HTTP date, or the Unix timestamp of the reset;
  # nil without one, so the backoff applies.
  def self.wait_for(value)
    return if value.blank?

    number = Float(value, exception: false)
    return [number - Time.now.to_f, 0].max if number && number > TIMESTAMP_FLOOR
    return number if number

    Time.httpdate(value) - Time.current
  rescue ArgumentError
    nil
  end

  private

  def connection(token, adapter, retry_interval)
    Faraday.new(url: BASE_URL, headers: { 'Shortcut-Token' => token }) do |faraday|
      # Outermost, so it raises only for the response the retries end on
      faraday.response :raise_error, include_request: false
      faraday.request :json
      # Story search is a POST that only reads, so it is retried like a GET
      faraday.request :retry, max: RETRIES, interval: retry_interval, backoff_factor: 2,
                              max_interval: LONGEST_WAIT, retry_statuses: RETRY_STATUSES, methods: %i[get post],
                              exceptions: Faraday::Retry::Middleware::DEFAULT_EXCEPTIONS + [Faraday::ConnectionFailed],
                              header_parser_block: self.class.method(:wait_for), retry_block: method(:log_retry)
      faraday.response :json
      faraday.adapter(*Array(adapter))
    end
  end

  def request(method, path, body = nil)
    pace
    @connection.run_request(method, path, body, nil).body
  rescue Faraday::Error => e
    raise (e.is_a?(Faraday::ResourceNotFound) ? NotFound : Error),
          "Shortcut answered #{e.response_status || 'nothing'} to #{method.upcase} #{path}", cause: nil
  end

  def pace
    now = @clock.call
    elapsed = @last_request_at && (now - @last_request_at)
    @sleep.call(MINIMUM_INTERVAL - elapsed) if elapsed && elapsed < MINIMUM_INTERVAL
    @last_request_at = @clock.call
  end

  def log_retry(env:, will_retry_in:, **)
    Rails.logger.warn "Shortcut answered #{env.status || 'nothing'}; retrying in #{will_retry_in} seconds"
  end
end
