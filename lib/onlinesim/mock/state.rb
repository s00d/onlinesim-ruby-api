# frozen_string_literal: true

module OnlineSim
  class MockOnlineSim
    # One SMS received by an operation or a rent. `code` is extracted from `text` (nil when there is none);
    # `at` is the seconds after the mock epoch when it arrived; `id` and `created_at` are set for rent messages only.
    Sms = Struct.new(:service, :text, :code, :at, :id, :created_at, keyword_init: true)

    # A number operation. `number` has the `+`; `sum` (USD) is frozen while open, spent on close after an SMS,
    # refunded on close without one. `cursor` is the index of the SMS shown in `msg`; `next` moves it past the last.
    # `sum` is the API's field name; Enumerable#sum is not used on these records.
    Operation = Struct.new(:tzid, :service, :country, :number, :sum, :status, :messages, :cursor, # rubocop:disable Lint/StructNewOverride
                           keyword_init: true)

    # A rent. `number` has no country code, as the backend sends it for rents. `days` is the total period incl.
    # extensions, `initial_days` the period of getRentNum. `status` 0: reserved, waiting for the first SMS; 1: confirmed
    # by an SMS that is not `notify`, price charged. `sum` is the total cost incl. extensions, USD, frozen while
    # `status` is 0. `messages` are oldest first. Closed rents are removed.
    Rent = Struct.new(:tzid, :country, :number, :days, :initial_days, :status, :sum, :extension, :messages, # rubocop:disable Lint/StructNewOverride
                      keyword_init: true)

    # State of the mock backend: the single owner of everything the fake API remembers — balance, operations,
    # rents, the profile's webhook URL and its delivery log, scheduled SMS, the failure queue and the request
    # log. Handlers read and change it only through this object.
    #
    # Deterministic: ids and numbers come from a counter, timestamps from a fixed epoch plus that counter.
    # Money is kept in integer thousandths of a USD ("mills") so sums never drift.
    class State # rubocop:disable Metrics/ClassLength -- the single owner of the mock's state; splitting it would spread that state
      DEFAULT_PRICES = {
        7 => { "vkcom" => 0.5, "telegram" => 1.2, "google" => 0.3 },
        44 => { "google" => 0.2, "vkcom" => 0.36 }
      }.freeze
      DEFAULT_RENT_TARIFFS = { 7 => { days: { 1 => 1.0, 3 => 2.5, 7 => 5.0 }, extend: 1 } }.freeze

      USER_ID = 1
      # Seconds an operation stays open, as reported in `time`. The mock has no clock, so it never runs down.
      OPERATION_TIME = 1200
      # Minutes an unconfirmed rent waits for its first SMS (`stop_time` = start + this).
      RENT_FIRST_SMS_MINUTES = 20
      # Sender of a rent SMS from a prohibited sender: it gets the Integer `code` 0 and does not confirm the rent.
      NOTIFY = "notify"
      # 2026-01-01 00:00:00 UTC.
      EPOCH = 1_767_225_600

      # `YYYY-MM-DD HH:MM:SS` at `seconds` after the fixed mock epoch.
      def self.stamp(seconds = 0)
        Time.at(EPOCH + seconds).utc.strftime("%Y-%m-%d %H:%M:%S")
      end

      # The code rule shared by every SDK mock: dashes/spaces between digits are removed, then the first run of
      # 4–8 digits (not part of a longer run) is the code; nil when there is none.
      def self.extract_code(text)
        text.gsub(/(\d)[\s-]+(?=\d)/, '\1')[/(?<!\d)\d{4,8}(?!\d)/]
      end

      def self.to_mills(usd) = (usd * 1000).round
      def self.from_mills(mills) = mills / 1000.0

      # Short (country-less) number for an id: deterministic, 9 digits.
      def self.short_number(id) = (900_000_000 + id).to_s

      attr_reader :api_key, :guard_interval, :prices, :rent_tariffs,
                  :operations, :rents, :webhook_logs, :requests, :failures, :scheduled
      # Total balance incl. the frozen part, and the part frozen by open operations and unconfirmed rents, mills.
      attr_accessor :balance, :frozen, :webhook_url

      def initialize(api_key: "mock-key", balance: 100, prices: nil, rent_tariffs: nil, guard_interval: 0)
        @api_key = api_key
        @guard_interval = guard_interval
        @prices = normalize_prices(prices || DEFAULT_PRICES)
        @rent_tariffs = normalize_tariffs(rent_tariffs || DEFAULT_RENT_TARIFFS)
        @start_balance = State.to_mills(balance)
        reset
      end

      def reset
        @balance = @start_balance
        @frozen = 0
        @operations = {}
        @rents = {}
        @webhook_url = nil
        @webhook_logs = []
        @requests = []
        @failures = []
        @scheduled = {}
        @seq = 0
      end

      # Available balance (total minus frozen), mills.
      def available = @balance - @frozen

      # The id the next operation/rent will get.
      def peek_id = @seq + 1

      def next_id = @seq += 1

      # Remove and return the first queued failure that applies to `path`.
      def take_failure(path)
        index = @failures.index { |f| f[:endpoint].nil? || f[:endpoint] == path }
        index && @failures.delete_at(index)
      end

      # An SMS arrives at operation or rent `tzid` now. Returns false when there is no open one.
      def deliver(tzid, text, service = nil)
        op = @operations[tzid]
        if op && op.status != "TZ_OVER_OK"
          sms = Sms.new(service: service || op.service, text: text, code: State.extract_code(text), at: @seq)
          op.messages << sms
          op.status = "TZ_NUM_ANSWER"
          # Activation: `+<digits>`, seconds left, the order time.
          record_webhook("receiving_sms", tzid, op.country, op.number, sms, OPERATION_TIME, State.stamp(op.tzid))
          return true
        end
        rent = @rents[tzid] or return false

        deliver_to_rent(rent, text, service || "other")
        true
      end

      def schedule(tzid, text, polls, service = nil)
        (@scheduled[tzid] ||= []) << { text: text, service: service, polls: polls }
      end

      # One state poll of `tzid`: delivers the scheduled SMS whose polls ran out, counts down the rest.
      def poll(tzid)
        list = @scheduled[tzid] or return
        due, rest = list.partition { |s| s[:polls] <= 0 }
        rest.each { |s| s[:polls] -= 1 }
        rest.empty? ? @scheduled.delete(tzid) : @scheduled[tzid] = rest
        # Dropped silently when the operation was closed meanwhile: a real SMS would not arrive either.
        due.each { |s| deliver(tzid, s[:text], s[:service]) }
      end

      private

      # The first SMS that is not `notify` confirms the rent: the reservation is charged.
      def deliver_to_rent(rent, text, service)
        id = next_id
        sms = Sms.new(service: service, text: text, code: State.extract_code(text), at: id, id: id, created_at: State.stamp(id))
        rent.messages << sms
        if rent.status.zero? && service != NOTIFY
          cost = State.to_mills(rent.sum)
          @frozen -= cost
          @balance -= cost
          rent.status = 1
        end
        # Rent: full number in digits without `+`, minutes left, the SMS time.
        minutes_left = rent.status == 1 ? rent.days * 24 * 60 : RENT_FIRST_SMS_MINUTES
        record_webhook("rent_sms", rent.tzid, rent.country, "#{rent.country}#{rent.number}", sms, minutes_left, sms.created_at)
      end

      # No HTTP call: the mock only records what the backend would have sent.
      def record_webhook(type, tzid, country, number, sms, time_left, time_start) # rubocop:disable Metrics/ParameterLists
        return unless @webhook_url

        time = State.stamp(sms.at)
        @webhook_logs << {
          "id" => @webhook_logs.size + 1, "user_id" => USER_ID, "webhook_url" => @webhook_url, "type" => type,
          "params" => {
            "webhook_type" => type, "operation_id" => tzid, "user_id" => USER_ID, "country_code" => country,
            "number" => number, "sender" => sms.service, "message" => sms.text, "code" => sms.code || "",
            "time_start" => time_start, "time_left" => time_left
          },
          "status" => "success", "error" => nil, "created_at" => time, "updated_at" => time
        }
      end

      # Country codes as Integers, service slugs as Strings, whatever the caller passed.
      def normalize_prices(prices)
        prices.to_h { |code, services| [Integer(code), services.to_h { |slug, usd| [slug.to_s, usd] }] }
      end

      def normalize_tariffs(tariffs)
        tariffs.to_h do |code, tariff|
          days = tariff.fetch(:days) { tariff.fetch("days") }
          [Integer(code), { days: days.to_h { |d, usd| [Integer(d), usd] }, extend: tariff.fetch(:extend) { tariff["extend"] } }]
        end
      end
    end
  end
end
