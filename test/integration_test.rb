# frozen_string_literal: true

# Opt-in integration test against a LOCAL backend. Skipped unless both are set:
#   ONLINESIM_IT_BASE=https://on.test/api/  ONLINESIM_IT_KEY=<apikey>
# With ONLINESIM_IT_MOCK=1 it also runs the number lifecycle on the provider-free `test` driver
# (`spec/verify/backend_mock.php setup` first, a key of a user without webhook_url, teardown after).

require "test_helper"
require "openssl"

module Integration
  BASE = ENV.fetch("ONLINESIM_IT_BASE", nil)
  KEY = ENV.fetch("ONLINESIM_IT_KEY", nil)
  ENABLED = !(BASE.nil? || BASE.empty? || KEY.nil? || KEY.empty?)
  MOCK = ENV["ONLINESIM_IT_MOCK"] == "1"

  if ENABLED
    host = URI(BASE).host.to_s
    unless host == "localhost" || host == "127.0.0.1" || host.end_with?(".test", ".localhost")
      raise "refusing non-local integration host #{host}"
    end
  end

  # Test-only transport: local backends use a self-signed certificate. Not the SDK default.
  INSECURE = OnlineSim::NetHttpTransport.new(verify_mode: OpenSSL::SSL::VERIFY_NONE)

  def client
    @client ||= OnlineSim::Client.new(api_key: KEY, base_url: BASE, transport: INSECURE)
  end

  def setup
    skip "set ONLINESIM_IT_BASE and ONLINESIM_IT_KEY" unless ENABLED
  end
end

class IntegrationReadOnlyTest < Minitest::Test
  include Integration

  def test_balance
    b = client.user.balance
    assert_kind_of Float, b["balance"]
    assert_kind_of Float, b["zbalance"]
  end

  def test_profile
    assert_kind_of Integer, client.user.profile["id"]
  end

  def test_numbers_tariffs_one
    uk = client.numbers.tariffs_one(44)
    assert_equal 44, uk["code"]
    assert_kind_of Hash, uk["services"]
  end

  def test_numbers_state
    assert_kind_of Array, client.numbers.state
  end

  def test_rent_tariffs_one
    assert_equal 7, client.rent.tariffs_one(7)["code"]
  end

  def test_rent_state
    client.rent.state.each do |r|
      assert_kind_of Float, r["sum"]
      assert_kind_of Array, r["messages"]
      assert_kind_of Hash, r["extend"]
    end
  end

  def test_payment_history
    h = client.user.payment_history
    assert_kind_of Array, h["orders"]["data"]
    assert_kind_of Hash, h["paylist"]
  end

  def test_webhook_logs
    assert_kind_of Array, client.user.webhook_logs["data"]
  end

  def test_free_list
    f = client.free.list
    assert_kind_of Array, f["countries"]
    assert_kind_of Hash, f["numbers"]
  end

  def test_wrong_key
    bad = OnlineSim::Client.new(api_key: "wrong-key", base_url: BASE, transport: INSECURE)
    error = assert_raises(OnlineSim::ApiError) { bad.user.balance }
    assert_equal "ERROR_WRONG_KEY", error.code
  end
end

class IntegrationLifecycleTest < Minitest::Test
  include Integration

  COUNTRY = 44
  SERVICE = "google"

  def setup
    super
    skip "set ONLINESIM_IT_MOCK=1 (after backend_mock.php setup)" unless MOCK
  end

  # Inject an SMS through the test driver callback (local backends only, no auth).
  def inject_sms(tzid, text)
    status, = INSECURE.call("POST", URI.join(BASE, "sms_in_getaways/test").to_s,
                            { "Content-Type" => "application/json", "Accept" => "application/json" },
                            JSON.generate(id: tzid, phoneFrom: "VK", text: text), 30)
    assert_equal 200, status
  end

  def test_price_get_get_with_number_state_sms_wait_code_close
    assert_kind_of Numeric, client.numbers.price(SERVICE, COUNTRY)

    tzid = client.numbers.get(SERVICE, COUNTRY)
    assert_kind_of Integer, tzid
    order = client.numbers.get_with_number(SERVICE, COUNTRY)
    assert_match(/\A\+?44\d+\z/, order["number"])
    assert_equal COUNTRY, order["country"]

    ids = client.numbers.state.map { |op| op["tzid"] }
    assert_empty [tzid, order["tzid"]] - ids
    assert_match(/\ATZ_/, client.numbers.state_one(tzid)["response"])

    # The test driver answers NO_NUMBER to any reject list: proves `reject` is sent.
    assert_raises(OnlineSim::NoNumberError) { client.numbers.get(SERVICE, COUNTRY, reject: ["4470"]) }

    # No SMS yet: the guard interval keeps it open.
    error = assert_raises(OnlineSim::ApiError) { client.numbers.close(order["tzid"]) }
    assert_equal "NO_COMPLETE_TZID", error.code

    inject_sms(tzid, "VK: 195895 is your code")
    assert_equal "195895", client.numbers.wait_code(tzid, interval: 1, timeout: 30)
  end

  def test_set_webhook_url_validation_error_clear_webhook_url
    assert client.user.set_webhook_url("https://example.com/hook")
    assert_equal "https://example.com/hook", client.user.profile["webhook_url"]
    error = assert_raises(OnlineSim::ApiError) { client.user.set_webhook_url("not a url") }
    assert_equal "VALIDATION_ERROR", error.code
    assert client.user.clear_webhook_url
    assert_nil client.user.profile["webhook_url"]
  end
end
