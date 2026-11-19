# frozen_string_literal: true

require "net/http"
require "uri"

module OnlineSim
  # Default transport on stdlib Net::HTTP. Any object with the same `call` works (a fake in tests, a proxy setup).
  #
  # `call(method, url, headers, body, timeout)` returns `[status, body_string]` and raises on network errors
  # (`Timeout::Error` for a timeout). `timeout` (seconds) applies to connect, read and write separately.
  class NetHttpTransport
    # `start_options` go to `Net::HTTP.start`, e.g. `ca_file:`, `cert:`, `key:`. TLS is verified by default.
    def initialize(**start_options)
      @start_options = start_options
    end

    def call(method, url, headers, body, timeout)
      uri = URI(url)
      options = {
        use_ssl: uri.scheme == "https",
        open_timeout: timeout, read_timeout: timeout, write_timeout: timeout
      }.merge(@start_options)
      # Proxy from the environment (http_proxy / https_proxy / no_proxy), as Net::HTTP does by default.
      Net::HTTP.start(uri.host, uri.port, options) do |http|
        request = (method == "POST" ? Net::HTTP::Post : Net::HTTP::Get).new(uri, headers)
        request.body = body if body
        response = http.request(request)
        [response.code.to_i, String.new(response.body.to_s, encoding: Encoding::UTF_8)]
      end
    end
  end
end
