# frozen_string_literal: true

module OnlineSim
  # Base class of every error raised by the SDK.
  class Error < StandardError; end

  # The API answered with an error code in `response`.
  class ApiError < Error
    # Raw error code, e.g. "ERROR_WRONG_KEY".
    attr_reader :code

    def initialize(code, message = nil)
      @code = code
      super(message.nil? || message.empty? ? ERROR_MESSAGES.fetch(code, code) : message)
    end
  end

  # No number is available right now (NO_NUMBER). Retry later or pick another country.
  class NoNumberError < ApiError; end

  # Network failure, request timeout, or a response that is not JSON.
  class TransportError < Error
    # HTTP status, or nil when no response arrived (network error, timeout).
    attr_reader :status
    # Start of the response body (up to 500 chars), empty when none.
    attr_reader :body

    def initialize(message, status: nil, body: "")
      super(message)
      @status = status
      @body = body
    end
  end

  # `wait_code` gave up: no code arrived within its `timeout`.
  class TimeoutError < Error; end

  # Fallback messages for error codes the server sends without a `message`.
  ERROR_MESSAGES = {
    "ACCOUNT_BLOCKED" => "Account is blocked",
    "ACCOUNT_CLEANED" => "Account was deleted",
    "USER_NOT_ACTIVATED" => "Account email is not confirmed",
    "ERROR_WRONG_KEY" => "Wrong or missing API key",
    "ERROR_NO_SERVICE" => "Service is not specified",
    "API_ACCESS_DISABLED" => "API access is disabled in the profile",
    "API_ACCESS_IP" => "API access from this IP is not allowed in the profile",
    "ERROR_NO_TZID" => "tzid is not specified",
    "ERROR_WRONG_TZID" => "Wrong tzid",
    "ERROR_NO_OPERATIONS" => "No operations",
    "ERROR_UNDEFINED" => "Unexpected server error, try again",
    "NO_NUMBER" => "No numbers available for this service right now",
    "NO_COUNTRY" => "Country not found",
    "UNDEFINED_COUNTRY" => "Unknown country",
    "WARNING_LOW_BALANCE" => "Not enough balance",
    "EXCEEDED_CONCURRENT_OPERATIONS" => "Too many concurrent operations for this account",
    "INTERVAL_CONCURRENT_REQUESTS_ERROR" => "Too many concurrent requests, try again in a few seconds",
    "TRY_AGAIN_LATER" => "Rate limit exceeded or temporary error, try again later",
    "FORWARD_NOT_SUPPORTED" => "Number forwarding is no longer available",
    "ERROR_PARAMS" => "Wrong parameters",
    "NO_COMPLETE_TZID" => "The operation cannot be closed yet",
    "NO_CLOSE_RENT_US" => "US rent numbers cannot be closed early",
    "UNDEFINED_DAYS" => "Unknown rent period",
    "VALIDATION_ERROR" => "Validation failed",
    "0" => "Ban not applied: the operation already has an SMS",
    "TZ_OVER_OK" => "Operation finished without a new code",
    "ERROR_NO_ITEMS" => "Operation failed"
  }.freeze
end
