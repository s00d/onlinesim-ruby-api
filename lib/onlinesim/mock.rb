# frozen_string_literal: true

require "json"
require "uri"
require_relative "../onlinesim"
require_relative "mock/state"
require_relative "mock/handlers"

module OnlineSim
  # In-process fake OnlineSim API for tests: no network, no key, no money, no clock.
  # It is a transport (`call(method, url, headers, body, timeout)`, see NetHttpTransport) that answers like the
  # real backend; `mock.client` returns a normal OnlineSim::Client wired to it. Test helpers add SMS, queue
  # failures and expose the state.
  #
  #   mock = OnlineSim::MockOnlineSim.new(balance: 10)
  #   client = mock.client
  #   tzid = client.numbers.get("google", 44)
  #   mock.add_sms_after(tzid, "Your code: 123-456", 2)
  #   client.numbers.wait_code(tzid, interval: 0) # => "123456"
  class MockOnlineSim
    # Base URL of clients made by `client`. Never contacted: the mock answers in-process.
    BASE_URL = "https://mock.onlinesim.invalid/api/"

    # api_key        - key the mock accepts as "Authorization: Bearer <api_key>".
    # balance        - starting balance, USD.
    # prices         - number prices, country code => { service slug => USD }; replaces the defaults.
    # rent_tariffs   - rent tariffs, country code => { days: { days => USD }, extend: 1 | 0 }; replaces the defaults.
    # guard_interval - seconds; > 0: an operation without SMS, or an unconfirmed rent without any SMS, cannot be
    #                  closed (NO_COMPLETE_TZID).
    def initialize(api_key: "mock-key", balance: 100, prices: nil, rent_tariffs: nil, guard_interval: 0)
      @state = State.new(api_key: api_key, balance: balance, prices: prices, rent_tariffs: rent_tariffs,
                         guard_interval: guard_interval)
    end

    # The mock itself is the transport: pass it as `transport:` when you build the client yourself. Any base URL works.
    def transport = self

    # A normal client wired to the mock. `api_key` defaults to the mock's key; override it to test a wrong key.
    # Takes the other Client options (`lang:`, `dev_id:`, ...) except `transport:`.
    def client(**options)
      Client.new(api_key: @state.api_key, base_url: BASE_URL, **options, transport: self)
    end

    # An SMS arrives now at number operation or rent `tzid`. Raises ArgumentError when there is no open one.
    def add_sms(tzid, text, service: nil)
      raise ArgumentError, "MockOnlineSim: no open operation or rent #{tzid}" unless @state.deliver(tzid, text, service)
    end

    # The SMS arrives after `polls` state requests for `tzid` (getState / rent getRentState, listing it alone or
    # with others): with `polls = 2` the third poll sees it. Lets `wait_code` run with `interval: 0`.
    def add_sms_after(tzid, text, polls, service: nil)
      unless @state.operations.key?(tzid) || @state.rents.key?(tzid)
        raise ArgumentError, "MockOnlineSim: no operation or rent #{tzid}"
      end

      @state.schedule(tzid, text, polls, service)
    end

    # The next request (to `endpoint` only, e.g. "getNum.php", when given) answers {"response": code}.
    def fail_next(code, endpoint: nil)
      @state.failures << { code: code, endpoint: endpoint }
    end

    # The next request (to `endpoint` only, when given) fails at transport level: a non-JSON body with HTTP `status`.
    def fail_next_transport(status: 502, endpoint: nil)
      @state.failures << { status: status, endpoint: endpoint }
    end

    # Set the total balance, USD.
    def set_balance(usd) # rubocop:disable Naming/AccessorMethodName -- control API name shared by every SDK
      @state.balance = State.to_mills(usd)
    end

    # Total balance, USD, including the part frozen by open operations and unconfirmed rents (as `user.balance` reports it).
    def balance = State.from_mills(@state.balance)

    # Number operations, oldest first (deep copies).
    def operations = copy(@state.operations.values)

    # Open rents, oldest first (deep copies).
    def rents = copy(@state.rents.values)

    # Every request received, in order: { method:, path:, query:, body: }, `path` relative to `/api/`,
    # `query` with String keys and values, `body` the parsed JSON of a POST (nil for GET). A copy.
    def requests = copy(@state.requests)

    # Back to the constructor's state: balance, no operations, rents, logs, schedules or failures.
    def reset
      @state.reset
    end

    # The transport interface of OnlineSim::Client: returns [status, body].
    def call(method, url, headers, body, _timeout)
      uri = URI(url)
      path = uri.path
      at = path.index("/api/")
      req = {
        method: method.to_s.upcase,
        path: at ? path[(at + 5)..] : path.delete_prefix("/"),
        query: URI.decode_www_form(uri.query.to_s).to_h,
        body: body.is_a?(String) ? JSON.parse(body) : nil
      }
      @state.requests << req
      respond(req, headers)
    end

    def inspect
      "#<#{self.class.name} balance=#{balance} operations=#{@state.operations.size} rents=#{@state.rents.size}>"
    end

    private

    def respond(req, headers)
      failure = @state.take_failure(req[:path])
      if failure
        return failure.key?(:code) ? json({ "response" => failure[:code] }) : html(failure[:status], "Mock transport failure")
      end

      handler = Handlers::ROUTES[req[:path]]
      return html(404, "Not Found") unless handler

      # A wrong key is HTTP 456 (public endpoints check a sent key too); no key at all is HTTP 200.
      auth = authorization(headers)
      return json({ "response" => "ERROR_WRONG_KEY" }, 456) if !auth.nil? && auth != "Bearer #{@state.api_key}"
      return json({ "response" => "ERROR_WRONG_KEY" }) if auth.nil? && !Handlers::PUBLIC_PATHS.include?(req[:path])

      json(Handlers.public_send(handler, @state, req))
    end

    def authorization(headers)
      headers.find { |name, _| name.to_s.casecmp?("authorization") }&.last
    end

    def json(value, status = 200) = [status, JSON.generate(value)]

    def html(status, text) = [status, "<html><body>#{status} #{text}</body></html>"]

    def copy(value) = Marshal.load(Marshal.dump(value))
  end
end
