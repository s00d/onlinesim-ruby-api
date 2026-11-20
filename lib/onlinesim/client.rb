# frozen_string_literal: true

require "json"
require "uri"
require "timeout"

module OnlineSim
  DEFAULT_BASE_URL = "https://onlinesim.host/api/"

  # OnlineSim API client.
  #
  #   client = OnlineSim::Client.new(api_key: ENV["ONLINESIM_KEY"])
  #   client.user.balance["balance"]
  class Client
    DEFAULT_TIMEOUT = 30
    BODY_EXCERPT = 500

    attr_reader :numbers, :rent, :user, :free

    # api_key   - sent as "Authorization: Bearer <api_key>"; not needed for tariffs and free numbers.
    # base_url  - full API base, trailing slash optional.
    # lang      - `lang` query parameter.
    # dev_id    - `dev_id` query parameter, sent only when set.
    # timeout   - per-request timeout, seconds (Numeric).
    # transport - object with `call(method, url, headers, body, timeout)`; see NetHttpTransport.
    def initialize(api_key: nil, base_url: DEFAULT_BASE_URL, lang: "en", dev_id: nil, timeout: DEFAULT_TIMEOUT,
                   transport: NetHttpTransport.new)
      @api_key = blank?(api_key) ? nil : api_key.to_s
      @base_url = base_url.end_with?("/") ? base_url : "#{base_url}/"
      @lang = lang
      @dev_id = blank?(dev_id) ? nil : dev_id.to_s
      @timeout = timeout
      @transport = transport

      request = method(:request)
      @numbers = Numbers.new(request)
      @rent = Rent.new(request)
      @user = User.new(request)
      @free = Free.new(request)
    end

    def inspect
      "#<#{self.class.name} base_url=#{@base_url.inspect} lang=#{@lang.inspect}>"
    end

    private

    # The one request function the sections call. `endpoint` is relative to `base_url`, suffix included
    # ("getNum.php"). Query values: nil/""/[] omitted, booleans 1/0, arrays a comma list. `body` switches to POST.
    def request(endpoint, query: {}, body: nil)
      url = "#{@base_url}#{endpoint}"
      params = encode_query(query.merge(lang: @lang, dev_id: @dev_id))
      url = "#{url}?#{params}" unless params.empty?
      headers = { "Accept" => "application/json" }
      headers["Authorization"] = "Bearer #{@api_key}" if @api_key
      method = "GET"
      unless body.nil?
        method = "POST"
        headers["Content-Type"] = "application/json"
        body = JSON.generate(body)
      end

      status, text = send_request(method, url, headers, body)
      begin
        data = JSON.parse(text)
      rescue JSON::ParserError
        raise TransportError.new("HTTP #{status}: response is not JSON", status: status, body: text[0, BODY_EXCERPT])
      end
      # The body is checked before the status: a wrong key is HTTP 456 with {"response":"ERROR_WRONG_KEY"},
      # the rate limit HTTP 429 with {"response":"TRY_AGAIN_LATER"}.
      return unwrap(data) if data.is_a?(Hash) && data.key?("response")
      raise TransportError.new("HTTP #{status}", status: status, body: text[0, BODY_EXCERPT]) unless (200..299).cover?(status)

      data
    end

    def send_request(method, url, headers, body)
      @transport.call(method, url, headers, body, @timeout)
    rescue ::Timeout::Error
      raise TransportError, "Request timed out after #{@timeout} s"
    rescue StandardError => e
      raise TransportError, "Network error: #{e.message}"
    end

    # Success: strip `response`, return the rest. Error code: raise.
    def unwrap(data)
      response = data["response"]
      rest = data.except("response")
      return rest if [1, "1"].include?(response)

      if response.is_a?(Hash)
        # profile.php validation errors: {"response":{"webhook_url":["The webhook url must be a valid URL."]}}
        raise ApiError.new("VALIDATION_ERROR", response.values.flatten.join("; "))
      end

      code = response.to_s
      # Debug backends echo the code as `message`; prefer the readable fallback then.
      message = rest["message"].is_a?(String) && rest["message"] != code ? rest["message"] : nil
      raise NoNumberError.new(code, message) if code == "NO_NUMBER"

      raise ApiError.new(code, message)
    end

    def encode_query(query)
      pairs = query.filter_map do |key, value|
        value = value.join(",") if value.is_a?(Array)
        next if blank?(value)

        value = 1 if value == true
        value = 0 if value == false
        [key.to_s, value.to_s]
      end
      URI.encode_www_form(pairs)
    end

    def blank?(value)
      value.nil? || value == ""
    end
  end
end
