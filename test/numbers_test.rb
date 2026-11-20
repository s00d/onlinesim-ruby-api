# frozen_string_literal: true

require "test_helper"

class NumbersTest < Minitest::Test
  include ClientHelpers

  def test_price
    client, t = fake_client([{ json: { response: "1", price: 0.36 } }])
    assert_in_delta 0.36, client.numbers.price("vkcom", 44)
    assert_equal "/api/getPrice.php", t.last.path
    assert_equal({ "service" => "vkcom", "country" => "44" }, t.last.query)
  end

  def test_price_is_nil_when_the_server_has_none
    client, = fake_client([{ json: { response: "1", price: nil } }])
    assert_nil client.numbers.price("vkcom")
  end

  def test_get_sends_no_number_flag_and_reject_as_comma_list
    client, t = fake_client([{ json: { response: 1, tzid: 1520 } }])
    assert_equal 1520, client.numbers.get("google", 44, reject: ["4470", 4471])
    assert_equal "/api/getNum.php", t.last.path
    assert_equal({ "service" => "google", "country" => "44", "reject" => "4470,4471" }, t.last.query)
  end

  def test_get_defaults_to_country_7_and_omits_an_empty_reject
    client, t = fake_client([{ json: { response: 1, tzid: 1 } }])
    client.numbers.get("google", reject: [])
    assert_equal({ "service" => "google", "country" => "7" }, t.last.query)
  end

  def test_get_with_number_sends_number_1_and_returns_the_order
    order = { "tzid" => 1520, "number" => "+447459608320", "country" => 44, "time" => 1200, "service" => "google" }
    client, t = fake_client([{ json: { response: 1, **order } }])
    assert_equal order, client.numbers.get_with_number("google", 44)
    assert_equal({ "service" => "google", "country" => "44", "number" => "1" }, t.last.query)
  end

  def test_state_sends_booleans_as_1_0_lowercase_orderby_and_number_flag
    ops = fixture("getState")
    client, t = fake_client([{ json: ops }])
    result = client.numbers.state(order_by: "desc", msg_list: true)
    assert_equal ops, result
    assert_equal "195895", result[0]["msg"]
    assert_equal "/api/getState.php", t.last.path
    assert_equal({ "message_to_code" => "1", "orderby" => "desc", "msg_list" => "1", "number" => "1" }, t.last.query)
  end

  def test_state_defaults
    client, t = fake_client([{ json: [] }])
    client.numbers.state
    assert_equal({ "message_to_code" => "1", "orderby" => "asc", "msg_list" => "0", "number" => "1" }, t.last.query)
  end

  def test_state_returns_empty_on_error_no_operations
    client, = fake_client([{ json: { response: "ERROR_NO_OPERATIONS" } }])
    assert_equal [], client.numbers.state
  end

  def test_state_one_returns_the_operation
    op = fixture("getState")[0]
    client, t = fake_client([{ json: [op] }])
    assert_equal op, client.numbers.state_one(594, message_to_code: false)
    assert_equal({ "tzid" => "594", "message_to_code" => "0", "msg_list" => "0", "number" => "1" }, t.last.query)
  end

  def test_state_one_raises_error_no_operations
    client, = fake_client([{ json: { response: "ERROR_NO_OPERATIONS" } }, { json: [] }])
    2.times do
      error = assert_raises(OnlineSim::ApiError) { client.numbers.state_one(1) }
      assert_equal "ERROR_NO_OPERATIONS", error.code
    end
  end

  def test_next
    client, t = fake_client([{ json: { response: "1", tzid: "1520" } }])
    assert client.numbers.next(1520)
    assert_equal "/api/setOperationRevise.php", t.last.path
    assert_equal({ "tzid" => "1520" }, t.last.query)
  end

  def test_close
    client, t = fake_client([{ json: { response: 1, tzid: 1520 } }])
    assert client.numbers.close(1520)
    assert_equal "/api/setOperationOk.php", t.last.path
    assert_equal({ "tzid" => "1520" }, t.last.query)
  end

  def test_ban
    client, t = fake_client([{ json: { response: 1, tzid: 1520 } }])
    assert client.numbers.ban(1520)
    assert_equal({ "tzid" => "1520", "ban" => "1" }, t.last.query)
  end

  def test_ban_after_an_sms_surfaces_api_error_zero_with_a_readable_message
    client, = fake_client([{ json: { response: "0" } }])
    error = assert_raises(OnlineSim::ApiError) { client.numbers.ban(1520) }
    assert_equal ["0", "Ban not applied: the operation already has an SMS"], [error.code, error.message]
  end

  def test_next_accepts_the_string_tzid_answer_error_wrong_tzid_for_a_foreign_tzid
    client, = fake_client([{ json: { tzid: "1520", response: "1" } }, { json: { response: "ERROR_WRONG_TZID" } }])
    assert client.numbers.next(1520)
    assert_equal "ERROR_WRONG_TZID", assert_raises(OnlineSim::ApiError) { client.numbers.next(1) }.code
  end

  def test_state_one_accepts_an_operation_without_response
    client, = fake_client([{ json: [{ tzid: 5, country: 7, service: "vkcom", sum: 0.5, time: 900, form: "index" }] }])
    op = client.numbers.state_one(5)
    assert_equal 5, op["tzid"]
    assert_nil op["response"]
  end

  def test_close_surfaces_no_complete_tzid
    client, = fake_client([{ json: { response: "NO_COMPLETE_TZID" } }])
    error = assert_raises(OnlineSim::ApiError) { client.numbers.close(1) }
    assert_equal "NO_COMPLETE_TZID", error.code
  end

  def test_tariffs_requests_country_all_and_normalises_empty_services
    uk = fixture("getNumbersStats_44")
    client, t = fake_client([{ json: { "44" => uk, "7" => uk.merge("code" => 7, "services" => []) } }])
    all = client.numbers.tariffs
    assert_equal "/api/getNumbersStats.php", t.last.path
    assert_equal({ "country" => "all" }, t.last.query)
    assert_equal "vkcom", all["44"]["services"]["service_vkcom"]["slug"]
    assert_equal({}, all["7"]["services"])
  end

  def test_tariffs_one
    uk = fixture("getNumbersStats_44")
    client, t = fake_client([{ json: uk }])
    assert_equal uk, client.numbers.tariffs_one(44)
    assert_equal({ "country" => "44" }, t.last.query)
  end

  def test_tariffs_one_raises_no_country
    client, = fake_client([{ json: { response: "NO_COUNTRY" } }])
    error = assert_raises(OnlineSim::ApiError) { client.numbers.tariffs_one(999) }
    assert_equal "NO_COUNTRY", error.code
  end
end
