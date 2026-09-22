# Retries a GitHub call that hits the rate limit or a connection failure,
# waiting as long as GitHub's own headers ask before trying again.
module GithubRateLimiting
  MAX_RETRIES = 5

  private

  def with_rate_limit_handling
    retries = 0
    begin
      yield
    rescue Octokit::TooManyRequests => e
      raise 'Max retries reached. Unable to complete the request due to rate limiting.' unless retries < MAX_RETRIES

      wait_time = calculate_wait_time(e.response_headers, retries)
      Rails.logger.warn "Rate limit exceeded. Waiting for #{wait_time} seconds before retrying..."
      sleep(wait_time)
      retries += 1
      retry
    rescue Faraday::ConnectionFailed, Net::OpenTimeout => e
      Rails.logger.warn "ConnectionFailed or OpenTimeout error caught. retries: #{retries}"
      raise 'Max retries reached. Unable to complete the request due to connection issues.' unless retries < MAX_RETRIES

      wait_time = 5 * (2**retries) # exponential backoff
      Rails.logger.warn "Connection error: #{e.message}. Retrying in #{wait_time} seconds..."
      sleep(wait_time)
      retries += 1
      retry
    end
  end

  def calculate_wait_time(headers, retry_count)
    return exponential_backoff_starting_at_one_minute retry_count if headers.nil?

    if headers['retry-after']
      headers['retry-after'].to_i
    elsif headers['x-ratelimit-remaining'].to_i == 0 && headers['x-ratelimit-reset']
      wait_time = [headers['x-ratelimit-reset'].to_i - Time.current.to_i, 0].max

      # If we're still hitting rate limits and wait time is 0,
      # use exponential backoff instead
      wait_time = exponential_backoff_starting_at_one_minute retry_count if wait_time == 0

      wait_time
    else
      exponential_backoff_starting_at_one_minute retry_count
    end
  end

  def exponential_backoff_starting_at_one_minute(retry_count)
    60 * (2**retry_count)
  end
end
