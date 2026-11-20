# frozen_string_literal: true

require "test_helper"

class UserTest < Minitest::Test
  include ClientHelpers

  def test_balance_sends_income_1_and_parses_the_decimal_string
    client, t = fake_client([{ json: fixture("getBalance") }])
    assert_equal({ "balance" => 1442.33, "zbalance" => 1023.41, "income" => 9.78 }, client.user.balance)
    assert_equal "/api/getBalance.php", t.last.path
    assert_equal({ "income" => "1" }, t.last.query)
  end

  def test_balance_without_income
    client, = fake_client([{ json: { response: "1", balance: "0.000", zbalance: 0 } }])
    balance = client.user.balance
    assert_equal({ "balance" => 0.0, "zbalance" => 0.0 }, balance)
    assert_kind_of Float, balance["zbalance"]
  end

  def test_profile
    client, t = fake_client([{ json: fixture("getProfile") }])
    profile = client.user.profile
    assert_equal "/api/getProfile.php", t.last.path
    assert_equal [1, "https://example.com/hook", ["333"]], profile.values_at("id", "webhook_url", "number_reject")
  end

  def test_profile_decodes_number_as_int_or_nil_and_country_as_string_or_nil
    client, = fake_client([{ json: { response: "1", profile: { id: 1, number: 79_001_234_567, country: "RU" } } }])
    assert_equal [79_001_234_567, "RU"], client.user.profile.values_at("number", "country")
  end

  def test_payment_history_keeps_a_paylist_that_arrives_as_a_json_array_nullable_order_fields
    body = fixture("getPaymentHistory")
    order = { "id" => 1, "sum" => "10.00", "currency" => nil, "form_text" => nil, "stat" => 0,
              "created_at" => "2026-06-14 09:12:12" }
    paylist = [{ "id" => 0, "name" => "Card" }, { "id" => 1, "name" => "Crypto" }]
    client, = fake_client([{ json: body.merge("paylist" => paylist, "orders" => body["orders"].merge("data" => [order])) }])
    history = client.user.payment_history
    assert_equal paylist, history["paylist"]
    assert_equal [nil, nil], history["orders"]["data"][0].values_at("currency", "form_text")
  end

  def test_payment_history_keeps_an_empty_paylist
    client, t = fake_client([{ json: fixture("getPaymentHistory") }])
    history = client.user.payment_history(2)
    assert_equal "/api/getPaymentHistory.php", t.last.path
    assert_equal({ "page" => "2" }, t.last.query)
    assert_equal([], history["paylist"])
    assert_equal [9462, "89.00"], history["orders"]["data"][0].values_at("id", "sum")
  end

  def test_set_webhook_url_posts_json
    client, t = fake_client([{ json: { response: "1", user: { id: 2 } } }])
    assert client.user.set_webhook_url("https://example.com/hook")
    call = t.last
    assert_equal "POST", call.http_method
    assert_equal "/api/profile.php", call.path
    assert_equal "application/json", call.headers["Content-Type"]
    assert_equal "Bearer test-key", call.headers["Authorization"]
    assert_equal({ "profile" => { "webhook_url" => "https://example.com/hook" } }, call.json_body)
  end

  def test_clear_webhook_url_posts_webhook_url_null
    client, t = fake_client([{ json: { response: "1", user: { id: 2 } } }])
    assert client.user.clear_webhook_url
    assert_equal "POST", t.last.http_method
    assert_equal({ "profile" => { "webhook_url" => nil } }, t.last.json_body)
  end

  def test_webhook_logs_returns_the_paginator
    page = {
      "current_page" => 1,
      "data" => [{
        "id" => 7, "user_id" => 2, "webhook_url" => "https://example.com/hook", "type" => "receiving_sms",
        "params" => { "webhook_type" => "receiving_sms", "operation_id" => 1520, "code" => "195895" },
        "status" => "success", "error" => nil,
        "created_at" => "2026-11-19 10:00:01", "updated_at" => "2026-11-19 10:00:01"
      }],
      "from" => 1, "to" => 1, "last_page" => 1, "per_page" => 10, "total" => 1
    }
    client, t = fake_client([{ json: { response: "1", data: page } }])
    assert_equal page, client.user.webhook_logs
    assert_equal "/api/webhook-logs", t.last.path
    assert_equal({ "page" => "1" }, t.last.query)
  end
end
