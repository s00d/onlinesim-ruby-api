# frozen_string_literal: true

require "test_helper"

class WaitCodeTest < Minitest::Test
  include ClientHelpers

  # Fake numbers section on a fake clock: `sleep` only moves `now`, nothing really waits.
  class FakeNumbers
    attr_reader :log, :clock

    def initialize(steps)
      @steps = steps.dup
      @log = []
      @clock = 0
    end

    def state_one(tzid, message_to_code: true)
      @log << "state #{tzid} code=#{message_to_code}"
      step = @steps.shift || {}
      raise step if step.is_a?(Exception)

      { "tzid" => tzid, "response" => "TZ_NUM_WAIT" }.merge(step)
    end

    def close(tzid)
      @log << "close #{tzid}"
      true
    end

    def next(tzid)
      @log << "next #{tzid}"
      true
    end

    def sleep
      lambda { |seconds|
        @log << "sleep #{seconds}"
        @clock += seconds
      }
    end

    def now = -> { @clock }

    def wait(tzid, **options)
      OnlineSim.wait_code(self, tzid, sleep: sleep, now: now, **options)
    end
  end

  def test_returns_the_code_once_it_arrives_and_closes_the_operation
    f = FakeNumbers.new([{}, {}, { "response" => "TZ_NUM_ANSWER", "msg" => "195895" }])
    assert_equal "195895", f.wait(7)
    assert_equal ["state 7 code=true", "sleep 5", "state 7 code=true", "sleep 5", "state 7 code=true", "close 7"], f.log
  end

  def test_keep_open_calls_next_since_skips_the_previous_code_full_message_asks_for_text
    f = FakeNumbers.new([{ "msg" => "old" }, { "msg" => "Your code is 2991" }])
    assert_equal "Your code is 2991", f.wait(7, keep_open: true, since: "old", full_message: true, interval: 1)
    assert_equal ["state 7 code=false", "sleep 1", "state 7 code=false", "next 7"], f.log
  end

  def test_raises_api_error_at_once_for_a_finished_operation
    %w[TZ_OVER_OK ERROR_NO_ITEMS].each do |status|
      f = FakeNumbers.new([{ "response" => status }])
      error = assert_raises(OnlineSim::ApiError) { f.wait(7) }
      assert_equal status, error.code
      assert_equal ["state 7 code=true"], f.log
    end
  end

  def test_a_finished_operation_that_still_carries_a_new_code_returns_it
    f = FakeNumbers.new([{ "response" => "TZ_OVER_OK", "msg" => "1234" }])
    assert_equal "1234", f.wait(7)
  end

  def test_raises_timeout_error_and_cuts_the_last_sleep_to_the_deadline
    f = FakeNumbers.new([])
    assert_raises(OnlineSim::TimeoutError) { f.wait(7, interval: 4, timeout: 10) }
    assert_equal ["sleep 4", "sleep 4", "sleep 2"], f.log.grep(/\Asleep/)
    assert_equal 4, f.log.grep(/\Astate/).size
    assert_equal 10, f.clock
  end

  def test_retries_a_transient_transport_error
    f = FakeNumbers.new([OnlineSim::TransportError.new("Network error: reset"), { "msg" => "42" }])
    assert_equal "42", f.wait(7)
    assert_equal ["state 7 code=true", "sleep 5", "state 7 code=true", "close 7"], f.log
  end

  def test_raises_any_api_error_at_once
    f = FakeNumbers.new([OnlineSim::ApiError.new("ERROR_NO_OPERATIONS")])
    error = assert_raises(OnlineSim::ApiError) { f.wait(7) }
    assert_equal "ERROR_NO_OPERATIONS", error.code
    assert_equal ["state 7 code=true"], f.log
  end

  def test_is_exposed_as_client_numbers_wait_code
    client, t = fake_client([{ json: [{ tzid: 9, response: "TZ_NUM_ANSWER", msg: "555" }] },
                             { json: { response: 1, tzid: 9 } }])
    assert_equal "555", client.numbers.wait_code(9, sleep: ->(_) { flunk "no sleep expected" })
    assert_equal ["/api/getState.php", "/api/setOperationOk.php"], t.calls.map(&:path)
  end
end
