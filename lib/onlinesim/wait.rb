# frozen_string_literal: true

# Ruby client for the OnlineSim API. Entry point: OnlineSim::Client.
module OnlineSim
  MONOTONIC = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
  private_constant :MONOTONIC

  # ApiError codes that mean "try again": rate limit (HTTP 429), a transient server error, too many requests.
  RETRYABLE_CODES = %w[TRY_AGAIN_LATER ERROR_UNDEFINED INTERVAL_CONCURRENT_REQUESTS_ERROR].freeze
  private_constant :RETRYABLE_CODES

  # Poll `numbers.state_one(tzid)` every `interval` seconds until a code different from `since` arrives, then
  # `close` (or `next` with `keep_open`) and return it. A finished operation (TZ_OVER_OK, ERROR_NO_ITEMS) without a
  # new code raises ApiError with that state as the code; running out of `timeout` seconds raises TimeoutError.
  # TransportError and the transient ApiError codes TRY_AGAIN_LATER, ERROR_UNDEFINED and
  # INTERVAL_CONCURRENT_REQUESTS_ERROR are retried until the timeout; any other ApiError is raised at once.
  # `sleep` (seconds -> any) and `now` (-> seconds) are injectable for tests.
  def self.wait_code(numbers, tzid, interval: 5, timeout: 600, keep_open: false, full_message: false, since: nil,
                     sleep: Kernel.method(:sleep), now: MONOTONIC)
    deadline = now.call + timeout
    loop do
      op = begin
        numbers.state_one(tzid, message_to_code: !full_message)
      rescue TransportError
        nil
      rescue ApiError => e
        raise unless RETRYABLE_CODES.include?(e.code)

        nil
      end

      if op
        msg = op["msg"]
        if msg.is_a?(String) && !msg.empty? && msg != since
          keep_open ? numbers.next(tzid) : numbers.close(tzid)
          return msg
        end
        raise ApiError, op["response"] if %w[TZ_OVER_OK ERROR_NO_ITEMS].include?(op["response"])
      end

      left = deadline - now.call
      raise TimeoutError, "No code for operation #{tzid} within #{timeout} s" if left <= 0

      sleep.call([interval, left].min)
    end
  end
end
