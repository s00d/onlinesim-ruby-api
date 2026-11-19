# frozen_string_literal: true

require "test_helper"

# MockOnlineSim through the real client: every endpoint, every control helper.
class MockTest < Minitest::Test
  # wait_code options that never really sleep.
  NO_SLEEP = { interval: 0, sleep: ->(_) {} }.freeze

  def mock(**options) = OnlineSim::MockOnlineSim.new(**options)

  def assert_api_error(code, klass = OnlineSim::ApiError, &block)
    error = assert_raises(klass, &block)
    assert_equal code, error.code
    error
  end

  # ----- auth and transport -----

  def test_wrong_or_missing_key_answers_456_error_wrong_key_mapped_to_api_error
    m = mock
    ["nope", ""].each do |key|
      assert_api_error("ERROR_WRONG_KEY") { m.client(api_key: key).user.balance }
    end
  end

  def test_tariffs_and_free_numbers_need_no_key
    client = mock.client(api_key: nil)
    assert_equal 44, client.numbers.tariffs_one(44)["code"]
    assert_equal 7, client.rent.tariffs_one(7)["code"]
    assert_equal 44, client.free.list["messages"]["country"]
  end

  def test_works_as_the_transport_of_a_client_built_by_hand_with_any_base_url
    m = mock(api_key: "k", balance: 5)
    client = OnlineSim::Client.new(api_key: "k", transport: m.transport)
    assert_equal({ "balance" => 5.0, "zbalance" => 0.0, "income" => 0.0 }, client.user.balance)
    assert_equal [{ method: "GET", path: "getBalance.php", query: { "income" => "1", "lang" => "en" }, body: nil }], m.requests
  end

  def test_an_unknown_endpoint_is_a_non_json_404
    status, body = mock.call("GET", "https://x.test/api/nope.php", {}, nil, 30)
    assert_equal 404, status
    assert_match(/Not Found/, body)
  end

  # ----- numbers -----

  def test_price_null_for_unknown_service_undefined_country_for_unknown_country
    client = mock.client
    assert_in_delta 1.2, client.numbers.price("telegram", 7)
    assert_nil client.numbers.price("nope", 7)
    assert_api_error("UNDEFINED_COUNTRY") { client.numbers.price("google", 999) }
  end

  def test_get_freezes_the_price_numbers_are_deterministic_get_with_number_returns_the_order
    m = mock
    client = m.client
    assert_equal 1, client.numbers.get("google", 44)
    assert_equal({ "tzid" => 2, "number" => "+7900000002", "country" => 7, "time" => 1200, "service" => "vkcom" },
                 client.numbers.get_with_number("vkcom"))
    assert_equal([nil, "1"], m.requests.map { |r| r[:query]["number"] })
    assert_equal({ "balance" => 100.0, "zbalance" => 0.7, "income" => 0.0 }, client.user.balance)
    assert_equal([[1, "+44900000001", "TZ_NUM_WAIT"], [2, "+7900000002", "TZ_NUM_WAIT"]],
                 m.operations.map { |o| [o.tzid, o.number, o.status] })
  end

  def test_get_errors_unknown_country_service_low_balance_reject
    m = mock(balance: 0.25)
    client = m.client
    assert_api_error("UNDEFINED_COUNTRY") { client.numbers.get("google", 999) }
    assert_api_error("ERROR_NO_SERVICE") { client.numbers.get("nope", 7) }
    assert_api_error("WARNING_LOW_BALANCE") { client.numbers.get("google", 7) }
    assert_api_error("NO_NUMBER", OnlineSim::NoNumberError) { client.numbers.get("google", 44, reject: %w[4490 7]) }
    assert_equal "4490,7", m.requests.last[:query]["reject"]
    # a non-matching reject passes; the rejected attempt did not consume a number
    assert_equal "+44900000001", client.numbers.get_with_number("google", 44, reject: ["4480"])["number"]
    # 0.25 - 0.2 frozen = 0.05 available
    assert_api_error("WARNING_LOW_BALANCE") { client.numbers.get("google", 44) }
  end

  def test_state_lifecycle_wait_answer_over
    m = mock
    client = m.client
    assert_equal [], client.numbers.state
    a = client.numbers.get("google", 44)
    b = client.numbers.get("vkcom", 7)
    one = client.numbers.state_one(a)
    assert_equal [a, "TZ_NUM_WAIT", "+44900000001", 0.2, 0],
                 one.values_at("tzid", "response", "number", "sum", "guard_interval_remaining_seconds")
    refute one.key?("msg")

    m.add_sms(a, "Your Google code is G-123 456. Do not share it.")
    assert_equal %w[TZ_NUM_ANSWER 123456], client.numbers.state_one(a).values_at("response", "msg")
    assert_equal "Your Google code is G-123 456. Do not share it.", client.numbers.state_one(a, message_to_code: false)["msg"]
    assert_equal([b, a], client.numbers.state(order_by: "desc").map { |o| o["tzid"] })

    client.numbers.close(a)
    assert_equal ["TZ_OVER_OK", 0], client.numbers.state_one(a).values_at("response", "time")
    assert_api_error("ERROR_NO_OPERATIONS") { client.numbers.state_one(999) }
  end

  def test_text_without_code_next_switches_sms_msg_list_lists_all
    m = mock
    client = m.client
    tzid = client.numbers.get("telegram")
    m.add_sms(tzid, "Welcome!", service: "telegram")
    assert_equal "Welcome!", client.numbers.state_one(tzid)["msg"]
    client.numbers.next(tzid)
    waiting = client.numbers.state_one(tzid)
    assert_equal "TZ_NUM_WAIT", waiting["response"]
    refute waiting.key?("msg")
    m.add_sms(tzid, "code 98765")
    assert_equal "98765", client.numbers.state_one(tzid)["msg"]
    assert_equal [{ "service" => "telegram", "msg" => "Welcome!" }, { "service" => "telegram", "msg" => "98765" }],
                 client.numbers.state_one(tzid, msg_list: true)["msg"]
    assert client.numbers.next(424_242) # always succeeds, like the backend
  end

  def test_close_spends_after_sms_refunds_without_ban_after_sms_answers_zero
    m = mock(balance: 10)
    client = m.client
    paid = client.numbers.get("telegram")
    empty = client.numbers.get("telegram")
    m.add_sms(paid, "1111")
    assert_api_error("0") { client.numbers.ban(paid) }
    client.numbers.close(paid)
    client.numbers.close(empty)
    assert_equal({ "balance" => 8.8, "zbalance" => 0.0, "income" => 0.0 }, client.user.balance)
    assert_in_delta 8.8, m.balance
    assert_api_error("ERROR_WRONG_TZID") { client.numbers.close(paid) }
    assert_api_error("ERROR_WRONG_TZID") { client.numbers.close(999) }
    banned = client.numbers.get("google")
    assert client.numbers.ban(banned)
    assert_equal "TZ_OVER_OK", m.operations.find { |o| o.tzid == banned }.status
  end

  def test_guard_interval_an_operation_without_sms_cannot_be_closed
    m = mock(guard_interval: 120)
    client = m.client
    tzid = client.numbers.get("google")
    assert_equal 120, client.numbers.state_one(tzid)["guard_interval_remaining_seconds"]
    assert_api_error("NO_COMPLETE_TZID") { client.numbers.close(tzid) }
    m.add_sms(tzid, "5555")
    assert_equal 0, client.numbers.state_one(tzid)["guard_interval_remaining_seconds"]
    assert client.numbers.close(tzid)
  end

  def test_wait_code_with_add_sms_after_and_zero_interval
    m = mock
    client = m.client
    tzid = client.numbers.get("google", 44)
    m.add_sms_after(tzid, "Your code: 4321", 2)
    assert_equal "4321", client.numbers.wait_code(tzid, interval: 0)
    assert_equal(%w[getNum.php getState.php getState.php getState.php setOperationOk.php], m.requests.map { |r| r[:path] })
    assert_equal "TZ_OVER_OK", m.operations.first.status
  end

  def test_wait_code_keep_open_and_since_polls_listing_all_operations_count_too
    m = mock
    client = m.client
    tzid = client.numbers.get("google", 44)
    m.add_sms_after(tzid, "1111", 0)
    first = client.numbers.wait_code(tzid, **NO_SLEEP, keep_open: true)
    m.add_sms_after(tzid, "2222", 1)
    client.numbers.state # one poll of every operation
    assert_equal "2222", client.numbers.wait_code(tzid, **NO_SLEEP, since: first)
  end

  def test_tariffs_from_prices
    client = mock.client
    all = client.numbers.tariffs
    assert_equal %w[7 44], all.keys
    assert_equal({ "count" => 100, "popular" => false, "code" => 44, "price" => 0.36, "id" => 2, "service" => "vkcom",
                   "slug" => "vkcom" }, all["44"]["services"]["service_vkcom"])
    assert_api_error("NO_COUNTRY") { client.numbers.tariffs_one(1) }
    empty = mock(prices: { 1 => {} }).client
    assert_equal({}, empty.numbers.tariffs_one(1)["services"]) # `[]` on the wire
  end

  # ----- rent -----

  def test_rent_get_state_extend_close
    m = mock(balance: 10)
    client = m.client
    rent = client.rent.get(7, 3)
    assert_equal [1, "900000001", 2.5, 3, 3 * 1440, 3 * 86_400, 1, []],
                 rent.values_at("tzid", "number", "sum", "days", "time", "time_seconds", "extension", "messages")
    assert_equal({ "1" => 1.0, "3" => 2.5, "7" => 5.0 }, rent["extend"])
    assert_in_delta 7.5, m.balance

    m.add_sms(rent["tzid"], "Bank: 777 888", service: "bank")
    m.add_sms(rent["tzid"], "no code here")
    messages = client.rent.state_one(rent["tzid"])["messages"]
    assert_equal([["other", ""], %w[bank 777888]], messages.map { |x| x.values_at("service", "code") }) # newest first

    assert_equal [4, 3.5], client.rent.extend(rent["tzid"], 1).values_at("days", "sum")
    assert_in_delta 6.5, m.balance

    fixed = client.rent.get(7, 1, extension: false)
    assert_equal [0, {}], fixed.values_at("extension", "extend")
    assert_api_error("TRY_AGAIN_LATER") { client.rent.extend(fixed["tzid"]) }
    assert_equal([rent["tzid"], fixed["tzid"]], client.rent.state.map { |r| r["tzid"] })

    client.rent.close(fixed["tzid"])
    assert_equal [rent["tzid"]], m.rents.map(&:tzid)
    assert_api_error("ERROR_NO_OPERATIONS") { client.rent.state_one(fixed["tzid"]) }
    assert_api_error("ERROR_WRONG_TZID") { client.rent.close(fixed["tzid"]) }
  end

  def test_rent_errors_unknown_country_unknown_days_low_balance
    client = mock(balance: 1.5).client
    assert_api_error("NO_COUNTRY") { client.rent.get(44) }
    assert_api_error("UNDEFINED_DAYS") { client.rent.get(7, 2) }
    assert_api_error("WARNING_LOW_BALANCE") { client.rent.get(7, 3) }
  end

  def test_add_sms_after_for_rents_tariffs_unknown_country
    m = mock
    client = m.client
    tzid = client.rent.get["tzid"]
    m.add_sms_after(tzid, "6060", 1)
    assert_equal [], client.rent.state_one(tzid)["messages"]
    assert_equal %w[6060 other], client.rent.state.first["messages"].first.values_at("code", "service")
    count = { "1" => 100, "3" => 100, "7" => 100 }
    assert_equal({ "7" => { "code" => 7, "enabled" => true, "name" => "russia", "new" => false, "position" => 7,
                            "count" => count, "days" => { "1" => 1.0, "3" => 2.5, "7" => 5.0 }, "extend" => 1,
                            "confirm" => false, "ext_counts" => count } }, client.rent.tariffs)
    assert_api_error("NO_COUNTRY") { client.rent.tariffs_one(44) }
  end

  # ----- user and free -----

  def test_profile_webhook_set_validate_clear_logs_recorded_when_sms_arrives
    m = mock(api_key: "secret")
    client = m.client
    assert_equal [1, "secret", nil], client.user.profile.values_at("id", "apikey", "webhook_url")
    error = assert_api_error("VALIDATION_ERROR") { client.user.set_webhook_url("ftp://x") }
    assert_equal "The webhook url must be a valid URL.", error.message
    client.user.set_webhook_url("https://example.com/hook")
    last = m.requests.last
    assert_equal ["POST", "profile.php", { "profile" => { "webhook_url" => "https://example.com/hook" } }],
                 last.values_at(:method, :path, :body)
    assert_equal "https://example.com/hook", client.user.profile["webhook_url"]

    tzid = client.numbers.get("google", 44)
    m.add_sms(tzid, "code 1234")
    rent = client.rent.get
    m.add_sms(rent["tzid"], "code 5678")
    logs = client.user.webhook_logs
    assert_equal [2, 1, 10], logs.values_at("total", "current_page", "per_page")
    assert_equal([["rent_sms", rent["tzid"], "5678"], ["receiving_sms", tzid, "1234"]],
                 logs["data"].map { |l| [l["type"], l["params"]["operation_id"], l["params"]["code"]] })

    client.user.clear_webhook_url
    assert_nil client.user.profile["webhook_url"]
  end

  def test_balance_includes_the_frozen_part_payment_history_is_empty
    m = mock(balance: 3)
    client = m.client
    client.numbers.get("telegram")
    assert_equal({ "balance" => 3.0, "zbalance" => 1.2, "income" => 0.0 }, client.user.balance)
    history = client.user.payment_history
    assert_equal({}, history["paylist"])
    assert_equal [[], 0, 1], history["orders"].values_at("data", "total", "current_page")
  end

  def test_free_list
    client = mock.client
    uk = client.free.list
    assert_equal [7, 44], uk["countries"].map { |c| c["country"] }.sort
    assert_equal ["7459608320"], uk["numbers"].keys
    assert_equal ["7459608320", 44, 2], uk["messages"].values_at("number", "country", "total")
    assert_equal "195895", uk["messages"]["data"].first["code"]
    ru = client.free.list(country: 7)
    assert_equal %w[51423 9001234567], ru["messages"]["data"].first.values_at("code", "my_number")
  end

  # ----- control API -----

  def test_fail_next_answers_an_error_code_once_optionally_for_one_endpoint
    m = mock
    client = m.client
    m.fail_next("NO_NUMBER", endpoint: "getNum.php")
    assert_in_delta 100, client.user.balance["balance"] # other endpoint: untouched
    assert_raises(OnlineSim::NoNumberError) { client.numbers.get("google") }
    assert_equal 1, client.numbers.get("google")
    m.fail_next("TRY_AGAIN_LATER")
    assert_api_error("TRY_AGAIN_LATER") { client.user.profile }
  end

  def test_fail_next_transport_fails_once_with_a_non_json_body_wait_code_retries_it
    m = mock
    client = m.client
    m.fail_next_transport
    error = assert_raises(OnlineSim::TransportError) { client.user.balance }
    assert_equal 502, error.status

    tzid = client.numbers.get("google")
    m.add_sms(tzid, "3030")
    m.fail_next_transport(status: 503, endpoint: "getState.php")
    assert_equal "3030", client.numbers.wait_code(tzid, **NO_SLEEP)
  end

  def test_add_sms_rejects_unknown_ids_set_balance_requests_log_reset
    m = mock(balance: 1)
    client = m.client(lang: "ru")
    assert_match(/no open operation or rent 5/, assert_raises(ArgumentError) { m.add_sms(5, "x") }.message)
    assert_match(/no operation or rent 5/, assert_raises(ArgumentError) { m.add_sms_after(5, "x", 1) }.message)
    m.set_balance(50)
    assert_in_delta 50, m.balance
    tzid = client.numbers.get("telegram")
    client.numbers.close(tzid)
    assert_raises(ArgumentError) { m.add_sms(tzid, "late") } # closed
    assert_equal({ method: "GET", path: "getNum.php", query: { "service" => "telegram", "country" => "7", "lang" => "ru" },
                   body: nil }, m.requests.first)

    m.fail_next("NO_NUMBER")
    m.reset
    assert_in_delta 1, m.balance
    assert_equal [], m.operations
    assert_equal [], m.rents
    assert_equal [], m.requests
    assert_equal 1, client.numbers.get("google", 44) # ids restart, failure queue cleared
  end

  def test_operations_and_requests_return_copies
    m = mock
    m.client.numbers.get("google")
    m.operations.first.status = "TZ_OVER_OK"
    m.requests.first[:path] = "x"
    assert_equal "TZ_NUM_WAIT", m.operations.first.status
    assert_equal "getNum.php", m.requests.first[:path]
  end

  def test_extract_code_rule
    code = OnlineSim::MockOnlineSim::State.method(:extract_code)
    assert_equal "123456", code.call("G-123 456")
    assert_equal "4321", code.call("code 4321, ref 99")
    assert_nil code.call("ref 123456789 only")
    assert_nil code.call("no digits")
  end
end
