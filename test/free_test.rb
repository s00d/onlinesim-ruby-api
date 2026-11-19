# frozen_string_literal: true

require "test_helper"

class FreeTest < Minitest::Test
  include ClientHelpers

  def test_list_has_no_php_suffix_and_sends_only_set_parameters
    client, t = fake_client([{ json: fixture("getFreeList") }])
    list = client.free.list(country: 44, number: "7459608320", count: 20)
    assert_equal "/api/getFreeList", t.last.path
    assert_equal({ "country" => "44", "number" => "7459608320", "count" => "20" }, t.last.query)
    assert_equal %w[countries numbers messages], list.keys
    assert_equal "447459608320", list["numbers"]["7459608320"]["full_number"]
    assert_equal "195895", list["messages"]["data"][0]["code"]
  end

  def test_list_normalises_empty_numbers
    client, t = fake_client([{ json: { response: 1, countries: [], numbers: [], messages: { data: [] } } }])
    assert_equal({}, client.free.list["numbers"])
    assert_equal({}, t.last.query)
  end
end
