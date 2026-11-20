# frozen_string_literal: true

require "test_helper"

class RentTest < Minitest::Test
  include ClientHelpers

  DETAIL = { "pagination" => "0", "number" => "1" }.freeze

  def state = fixture("rent_getRentState")

  def test_get_sends_extension_explicitly_pagination_and_number_and_parses_sum
    client, t = fake_client([{ json: { response: 1, item: state["list"][0] } }])
    rent = client.rent.get(7, 3)
    assert_equal "/api/rent/getRentNum.php", t.last.path
    assert_equal({ "country" => "7", "days" => "3", "extension" => "1", **DETAIL }, t.last.query)
    assert_in_delta 5.14, rent["sum"]
    assert_equal({ "1" => 14.7, "3" => 25.3, "7" => 51 }, rent["extend"])
    assert_equal "195895", rent["messages"][0]["code"]
  end

  def test_decodes_sum_as_a_number_or_a_string_and_code_0_for_a_notify_sms
    item = state["list"][0].merge(
      "status" => 0, "checked" => false, "sum" => 1.5,
      "messages" => [
        { "id" => 2, "service" => "notify", "text" => "Messages from this sender are not accepted", "code" => 0,
          "created_at" => "2026-11-19 10:01:12" },
        { "id" => 1, "service" => "Google", "text" => "G-070051", "code" => "070051", "created_at" => "2026-11-19 10:01:00" }
      ]
    )
    client, = fake_client([{ json: { response: 1, item: item } },
                           { json: { response: 1, list: [item.merge("sum" => "2.40")] } }])
    rent = client.rent.get(7, 3)
    assert_equal [0, false, 1.5], rent.values_at("status", "checked", "sum")
    assert_equal([0, "070051"], rent["messages"].map { |m| m["code"] })
    assert_in_delta 2.4, client.rent.state_one(rent["tzid"])["sum"]
  end

  def test_get_with_extension_false_sends_extension_0
    client, t = fake_client([{ json: { response: 1, item: state["list"][1] } }])
    client.rent.get(7, 1, extension: false)
    assert_equal "0", t.last.query["extension"]
  end

  def test_state_normalises_sum_and_the_empty_extend_map
    client, t = fake_client([{ json: state }])
    list = client.rent.state
    assert_equal "/api/rent/getRentState.php", t.last.path
    assert_equal DETAIL, t.last.query
    assert_equal([5.14, 0.0], list.map { |r| r["sum"] })
    assert_equal({}, list[1]["extend"])
  end

  def test_state_one
    client, t = fake_client([{ json: { response: 1, list: [state["list"][0]] } }])
    rent = client.rent.state_one(430)
    assert_equal [430, 5.14], rent.values_at("tzid", "sum")
    assert_equal({ "tzid" => "430", **DETAIL }, t.last.query)
  end

  def test_state_one_raises_error_no_operations_for_an_empty_list
    client, = fake_client([{ json: { response: 1, list: [] } }])
    error = assert_raises(OnlineSim::ApiError) { client.rent.state_one(1) }
    assert_equal "ERROR_NO_OPERATIONS", error.code
  end

  def test_extend
    client, t = fake_client([{ json: { response: 1, item: state["list"][0] } }])
    assert_equal 430, client.rent.extend(430, 3)["tzid"]
    assert_equal "/api/rent/extendRentState.php", t.last.path
    assert_equal({ "tzid" => "430", "days" => "3", **DETAIL }, t.last.query)
  end

  def test_extend_defaults_to_one_day
    client, t = fake_client([{ json: { response: 1, item: state["list"][0] } }])
    client.rent.extend(430)
    assert_equal "1", t.last.query["days"]
  end

  def test_tariffs
    tariffs = fixture("rent_tariffsRent")
    client, t = fake_client([{ json: tariffs }])
    assert_equal tariffs, client.rent.tariffs
    assert_equal "/api/rent/tariffsRent.php", t.last.path
    assert_equal({}, t.last.query)
  end

  def test_tariffs_one
    ru = fixture("rent_tariffsRent")["7"]
    client, t = fake_client([{ json: ru }])
    assert_equal ru, client.rent.tariffs_one
    assert_equal({ "country" => "7" }, t.last.query)
  end

  def test_tariffs_one_raises_no_country_for_the_empty_answer
    client, = fake_client([{ json: [] }])
    error = assert_raises(OnlineSim::ApiError) { client.rent.tariffs_one(999) }
    assert_equal "NO_COUNTRY", error.code
  end

  def test_close
    client, t = fake_client([{ json: { response: "1" } }])
    assert client.rent.close(430)
    assert_equal "/api/rent/closeRentNum.php", t.last.path
    assert_equal({ "tzid" => "430" }, t.last.query)
  end

  def test_close_surfaces_no_close_rent_us
    client, = fake_client([{ json: { response: "NO_CLOSE_RENT_US" } }])
    error = assert_raises(OnlineSim::ApiError) { client.rent.close(1) }
    assert_equal "NO_CLOSE_RENT_US", error.code
  end
end
