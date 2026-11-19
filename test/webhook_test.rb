# frozen_string_literal: true

require "test_helper"

class WebhookTest < Minitest::Test
  FULL = {
    "webhook_type" => "receiving_sms", "operation_id" => 1520, "user_id" => 2, "country_code" => 7,
    "number" => "+79001234567", "sender" => "VK", "message" => "VK: 195895 is your code", "code" => "195895",
    "time_start" => "2026-11-19 10:00:00", "time_left" => 1100
  }.freeze

  def test_parses_a_receiving_sms_json_string
    assert_equal FULL, OnlineSim.parse_webhook(JSON.generate(FULL))
  end

  def test_is_lenient_numeric_strings_missing_unknown_fields_and_types
    parsed = OnlineSim.parse_webhook({ webhook_type: "rent_sms", operation_id: "430", code: 2991, time_left: "soon",
                                       extra: true })
    assert_equal({ "webhook_type" => "rent_sms", "operation_id" => 430, "user_id" => nil, "country_code" => nil,
                   "number" => nil, "sender" => nil, "message" => nil, "code" => "2991", "time_start" => nil,
                   "time_left" => nil }, parsed)
    assert_nil OnlineSim.parse_webhook({ "webhook_type" => "other" })["webhook_type"]
  end

  def test_raises_only_for_input_that_is_not_a_json_object
    assert_raises(OnlineSim::Error) { OnlineSim.parse_webhook("not json") }
    error = assert_raises(OnlineSim::Error) { OnlineSim.parse_webhook("[1,2]") }
    assert_match "not a JSON object", error.message
    assert_raises(OnlineSim::Error) { OnlineSim.parse_webhook("null") }
  end
end
