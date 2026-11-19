# frozen_string_literal: true

require "test_helper"

class ClientTest < Minitest::Test
  include ClientHelpers

  def test_sends_the_key_as_bearer_header_never_in_query_plus_lang
    client, t = fake_client([{ json: { response: "1", price: 0.36 } }])
    client.numbers.price("vkcom", 44)
    call = t.last
    assert_equal "GET", call.http_method
    assert_equal "Bearer test-key", call.headers["Authorization"]
    assert_equal "application/json", call.headers["Accept"]
    params = URI.decode_www_form(call.uri.query).to_h
    refute params.key?("apikey")
    assert_equal "en", params["lang"]
    refute params.key?("dev_id")
    assert_equal 30, call.timeout
  end

  def test_applies_lang_dev_id_timeout_and_base_url_without_trailing_slash
    client, t = fake_client([{ json: { response: "1", price: 1 } }],
                            base_url: "https://api.test/api", lang: "ru", dev_id: 42, timeout: 2.5)
    client.numbers.price("vkcom")
    call = t.last
    assert_equal "https://api.test/api/getPrice.php", call.url.split("?").first
    params = URI.decode_www_form(call.uri.query).to_h
    assert_equal "ru", params["lang"]
    assert_equal "42", params["dev_id"]
    assert_in_delta 2.5, call.timeout
  end

  def test_sends_no_authorization_header_without_a_key
    client, t = fake_client([{ json: { response: "1", price: 1 } }], api_key: nil)
    client.numbers.price("vkcom")
    refute t.last.headers.key?("Authorization")
  end

  def test_uses_onlinesim_host_by_default
    t = FakeTransport.new([{ json: { response: "1", price: 1 } }])
    OnlineSim::Client.new(api_key: "k", transport: t).numbers.price("vkcom")
    assert t.last.url.start_with?("https://onlinesim.host/api/getPrice.php?")
  end

  def test_nested_endpoints_have_no_double_slash
    client, t = fake_client([{ json: { response: "1" } }], base_url: "https://api.test/api/")
    client.rent.close(1)
    assert_equal "https://api.test/api/rent/closeRentNum.php", t.last.url.split("?").first
  end

  def test_inspect_does_not_leak_the_key
    client, = fake_client([])
    refute_includes client.inspect, "test-key"
  end

  def test_maps_no_number_to_no_number_error
    client, = fake_client([{ json: { response: "NO_NUMBER" } }])
    error = assert_raises(OnlineSim::NoNumberError) { client.numbers.get("google", 44) }
    assert_kind_of OnlineSim::ApiError, error
    assert_equal "NO_NUMBER", error.code
    assert_equal "No numbers available for this service right now", error.message
  end

  def test_maps_no_number_for_forward_to_no_number_error
    client, = fake_client([{ json: { response: "NO_NUMBER_FOR_FORWARD" } }])
    assert_raises(OnlineSim::NoNumberError) { client.numbers.get("google") }
  end

  def test_maps_http_456_wrong_key_to_api_error_not_transport_error
    client, = fake_client([{ status: 456, json: { response: "ERROR_WRONG_KEY" } }])
    error = assert_raises(OnlineSim::ApiError) { client.user.balance }
    refute_kind_of OnlineSim::TransportError, error
    assert_equal "ERROR_WRONG_KEY", error.code
    assert_equal "Wrong API key", error.message
  end

  def test_prefers_the_server_message_but_not_when_it_echoes_the_code
    client, = fake_client([
                            { json: { response: "TRY_AGAIN_LATER", message: "Maintenance until 12:00" } },
                            { json: { response: "UNDEFINED_COUNTRY", message: "UNDEFINED_COUNTRY" } },
                            { json: { response: "SOMETHING_NEW" } }
                          ])
    [["TRY_AGAIN_LATER", "Maintenance until 12:00"], ["UNDEFINED_COUNTRY", "Unknown country"],
     %w[SOMETHING_NEW SOMETHING_NEW]].each do |code, message|
      error = assert_raises(OnlineSim::ApiError) { client.numbers.get("x") }
      assert_equal [code, message], [error.code, error.message]
    end
  end

  def test_maps_a_validation_object_to_validation_error_with_field_messages
    client, = fake_client([{ json: { response: { webhook_url: ["The webhook url must be a valid URL.", "Too long."],
                                                 name: ["Required."] } } }])
    error = assert_raises(OnlineSim::ApiError) { client.user.set_webhook_url("nope") }
    assert_equal "VALIDATION_ERROR", error.code
    assert_equal "The webhook url must be a valid URL.; Too long.; Required.", error.message
  end

  def test_maps_a_non_json_body_to_transport_error_with_status_and_excerpt
    client, = fake_client([{ status: 502, raw: "<html>Bad gateway</html>" }])
    error = assert_raises(OnlineSim::TransportError) { client.user.balance }
    assert_equal 502, error.status
    assert_equal "<html>Bad gateway</html>", error.body
  end

  def test_cuts_the_body_excerpt_to_500_chars
    client, = fake_client([{ status: 200, raw: "x" * 600 }])
    error = assert_raises(OnlineSim::TransportError) { client.user.balance }
    assert_equal 500, error.body.size
  end

  def test_maps_a_json_error_status_without_response_to_transport_error
    client, = fake_client([{ status: 500, json: { error: "boom" } }])
    error = assert_raises(OnlineSim::TransportError) { client.user.balance }
    assert_equal 500, error.status
  end

  def test_maps_a_network_failure_to_transport_error_without_status
    client, = fake_client([Errno::ECONNRESET.new("peer")])
    error = assert_raises(OnlineSim::TransportError) { client.user.balance }
    assert_nil error.status
    assert_equal "Network error: Connection reset by peer - peer", error.message
  end

  def test_maps_a_request_timeout_to_transport_error
    client, = fake_client([Net::ReadTimeout.new], timeout: 30)
    error = assert_raises(OnlineSim::TransportError) { client.user.balance }
    assert_nil error.status
    assert_equal "Request timed out after 30 s", error.message
  end

  def test_returns_bodies_without_response_as_they_are
    client, = fake_client([{ json: [] }])
    assert_equal [], client.numbers.state
  end
end
