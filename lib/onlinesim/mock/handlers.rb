# frozen_string_literal: true

require "uri"

module OnlineSim
  class MockOnlineSim
    # The mock's routes: endpoint path (relative to `/api/`) → handler. A handler gets the state and the request
    # and returns the JSON value the real backend would send (HTTP 200). Shapes follow the OpenAPI spec and the
    # live captures: `response` as int or string per endpoint, decimal-string money, `[]` for empty maps.
    # Auth, queued failures, 456 and 404 are the transport's job (MockOnlineSim#call), not the handlers'.
    module Handlers # rubocop:disable Metrics/ModuleLength -- one small function per endpoint; size follows the API
      module_function

      # Endpoints that answer without a key.
      PUBLIC_PATHS = ["getNumbersStats.php", "rent/tariffsRent.php", "getFreeList"].freeze

      COUNTRY_NAMES = { 7 => %w[russia Russia], 44 => ["united_kingdom", "United Kingdom"] }.freeze

      PROFILE = {
        "id" => State::USER_ID, "hash_id" => "mock", "name" => "mock@example.com", "username" => "mock@example.com",
        "email" => "mock@example.com", "email_verified_at" => State.stamp, "active" => "true", "api_access" => true,
        "is_api" => true, "number" => nil, "country" => nil, "locale" => "en", "currency" => "USD",
        "number_region" => nil, "number_country" => nil, "number_reject" => [], "ugroup" => 1, "verify" => 0,
        "block" => 0, "resetCount" => nil, "created_at" => State.stamp, "notification_at" => nil,
        "first_login" => false, "sub" => 0, "disable" => false, "is_project_subscription" => false
      }.freeze

      FREE = {
        44 => {
          name: "united_kingdom", text: "United Kingdom",
          numbers: { "7459608320" => [["Amazon", "Amazon: Use 195895 to reset your password."],
                                      ["Microsoft", "Microsoft access code: 2991"]] }
        },
        7 => { name: "russia", text: "Russia", numbers: { "9001234567" => [["Telegram", "Telegram code: 51423"]] } }
      }.freeze

      def error(code) = { "response" => code }

      def flag?(req, key)
        value = req[:query][key]
        !value.nil? && value != "0"
      end

      def int(req, key, fallback)
        value = req[:query][key]
        value.nil? ? fallback : Integer(value, 10, exception: false) || fallback
      end

      # USD with `digits` decimals, as the backend sends `balance` and rent `sum`.
      def decimal(mills, digits = 3) = format("%.#{digits}f", State.from_mills(mills))

      def country_name(code) = COUNTRY_NAMES.fetch(code) { ["country_#{code}", "Country #{code}"] }

      # Laravel paginator over `items`.
      def paginate(items, page, per_page, path)
        total = items.size
        last_page = [1, (total.to_f / per_page).ceil].max
        data = items[((page - 1) * per_page), per_page] || []
        url = ->(p) { "https://onlinesim.host/api/#{path}?page=#{p}" }
        {
          "current_page" => page, "data" => data, "first_page_url" => url.call(1),
          "from" => data.empty? ? nil : ((page - 1) * per_page) + 1, "last_page" => last_page,
          "last_page_url" => url.call(last_page), "links" => [],
          "next_page_url" => page < last_page ? url.call(page + 1) : nil,
          "path" => "https://onlinesim.host/api/#{path}", "per_page" => per_page,
          "prev_page_url" => page > 1 ? url.call(page - 1) : nil,
          "to" => data.empty? ? nil : ((page - 1) * per_page) + data.size, "total" => total
        }
      end

      # ----- numbers -----

      def msg_of(sms, to_code) = to_code ? sms.code || sms.text : sms.text

      def operation_view(state, operation, req)
        to_code = flag?(req, "message_to_code")
        open = operation.status != "TZ_OVER_OK"
        view = {
          "country" => operation.country, "sum" => operation.sum, "service" => operation.service, "number" => operation.number,
          "subscription_package_id" => nil, "webhook_url" => state.webhook_url, "response" => operation.status,
          "tzid" => operation.tzid, "time" => open ? State::OPERATION_TIME : 0, "form" => "index"
        }
        if flag?(req, "msg_list")
          unless operation.messages.empty?
            view["msg"] = operation.messages.map do |s|
              { "service" => s.service, "msg" => msg_of(s, to_code) }
            end
          end
        elsif (current = operation.messages[operation.cursor])
          view["msg"] = msg_of(current, to_code)
        end
        unless req[:query]["number"].nil?
          view["guard_interval_remaining_seconds"] = open && operation.messages.empty? ? state.guard_interval : 0
        end
        view
      end

      def get_price(state, req)
        prices = state.prices[int(req, "country", 7)] or return error("UNDEFINED_COUNTRY")
        { "response" => "1", "price" => prices[req[:query]["service"].to_s] }
      end

      def get_num(state, req)
        country = int(req, "country", 7)
        service = req[:query]["service"].to_s
        prices = state.prices[country] or return error("UNDEFINED_COUNTRY")
        price = prices[service] or return error("ERROR_NO_SERVICE")
        cost = State.to_mills(price)
        return error("WARNING_LOW_BALANCE") if state.available < cost

        number = "+#{country}#{State.short_number(state.peek_id)}"
        reject = req[:query]["reject"].to_s.split(",").reject(&:empty?)
        return error("NO_NUMBER") if reject.any? { |prefix| number[1..].start_with?(prefix) }

        tzid = state.next_id
        state.frozen += cost
        state.operations[tzid] = Operation.new(tzid: tzid, service: service, country: country, number: number, sum: price,
                                               status: "TZ_NUM_WAIT", messages: [], cursor: 0)
        return { "response" => 1, "tzid" => tzid } if req[:query]["number"].nil?

        { "response" => 1, "tzid" => tzid, "number" => number, "country" => country, "time" => State::OPERATION_TIME,
          "service" => service }
      end

      def get_state(state, req)
        ops = if req[:query]["tzid"].nil?
                state.operations.values
              else
                [state.operations[int(req, "tzid", -1)]].compact
              end
        ops.each { |op| state.poll(op.tzid) }
        return error("ERROR_NO_OPERATIONS") if ops.empty?

        ops = ops.sort_by(&:tzid)
        ops.reverse! if req[:query]["orderby"] == "desc"
        ops.map { |operation| operation_view(state, operation, req) }
      end

      def set_operation_revise(state, req)
        tzid = int(req, "tzid", 0)
        op = state.operations[tzid]
        # Always succeeds, even for unknown tzids, like the backend.
        if op && op.status != "TZ_OVER_OK"
          op.cursor = op.messages.size
          op.status = "TZ_NUM_WAIT"
        end
        { "response" => 1, "tzid" => tzid }
      end

      def set_operation_ok(state, req)
        tzid = int(req, "tzid", 0)
        op = state.operations[tzid]
        return error("ERROR_WRONG_TZID") if op.nil? || op.status == "TZ_OVER_OK"

        received = !op.messages.empty?
        return { "response" => "0" } if flag?(req, "ban") && received
        return error("NO_COMPLETE_TZID") if !received && state.guard_interval.positive?

        cost = State.to_mills(op.sum)
        state.frozen -= cost
        state.balance -= cost if received
        op.status = "TZ_OVER_OK"
        { "response" => 1, "tzid" => tzid }
      end

      def country_stat(state, code)
        name, locale = country_name(code)
        services = {}
        (state.prices[code] || {}).each_with_index do |(slug, price), i|
          services["service_#{slug}"] = { "count" => 100, "popular" => false, "code" => code, "price" => price,
                                          "id" => i + 1, "service" => slug, "slug" => slug }
        end
        { "name" => name, "position" => code, "code" => code, "other" => false, "new" => false, "enabled" => true,
          "services" => services.empty? ? [] : services, "locale_name" => locale }
      end

      def get_numbers_stats(state, req)
        if req[:query]["country"] == "all"
          all = state.prices.keys.to_h { |code| [code, country_stat(state, code)] }
          return all.empty? ? [] : all
        end
        code = int(req, "country", 7)
        state.prices.key?(code) ? country_stat(state, code) : error("NO_COUNTRY")
      end

      # ----- rent -----

      def rent_item(state, rent, req) # rubocop:disable Metrics/AbcSize
        tariff = state.rent_tariffs[rent.country]
        extendable = rent.extension && tariff && tariff[:extend] == 1
        start = rent.tzid
        item = {
          "status" => 1, "extension" => rent.extension ? 1 : 0,
          "messages" => rent.messages.reverse.map do |m|
            { "id" => m.id, "service" => m.service, "text" => m.text, "code" => m.code || "", "created_at" => m.created_at }
          end,
          "webhook_url" => state.webhook_url, "sum" => decimal(State.to_mills(rent.sum), 2), "country" => rent.country,
          "start_time" => State.stamp(start), "stop_time" => State.stamp(start + (rent.days * 86_400)),
          "checked_time" => State.stamp(start), "number" => rent.number, "days_autoextend" => 0, "rent" => 1,
          "tzid" => rent.tzid, "time" => rent.days * 24 * 60, "days" => rent.days, "hours" => rent.days * 24,
          "extend" => extendable ? tariff[:days].dup : [], "checked" => true, "reload" => nil,
          "day_extend" => extendable ? tariff[:days].fetch(1, 0) : 0, "m_ext" => false, "freeze" => false
        }
        item["time_seconds"] = rent.days * 86_400 unless req[:query]["number"].nil?
        item
      end

      def get_rent_num(state, req)
        country = int(req, "country", 7)
        tariff = state.rent_tariffs[country] or return error("NO_COUNTRY")
        days = int(req, "days", 1)
        price = tariff[:days][days] or return error("UNDEFINED_DAYS")
        return error("WARNING_LOW_BALANCE") if state.available < State.to_mills(price)

        tzid = state.next_id
        state.balance -= State.to_mills(price)
        # `extension` defaults to 1 on the server; `0` makes the rent non-extendable for good.
        rent = Rent.new(tzid: tzid, country: country, number: State.short_number(tzid), days: days, sum: price,
                        extension: req[:query]["extension"] != "0", messages: [])
        state.rents[tzid] = rent
        { "response" => 1, "item" => rent_item(state, rent, req) }
      end

      def get_rent_state(state, req)
        rents = if req[:query]["tzid"].nil?
                  state.rents.values
                else
                  [state.rents[int(req, "tzid", -1)]].compact
                end
        rents.each { |rent| state.poll(rent.tzid) }
        { "response" => 1, "list" => rents.map { |r| rent_item(state, r, req) } }
      end

      def extend_rent_state(state, req)
        rent = state.rents[int(req, "tzid", 0)] or return error("ERROR_WRONG_TZID")
        tariff = state.rent_tariffs[rent.country]
        return error("TRY_AGAIN_LATER") unless rent.extension && tariff && tariff[:extend] == 1

        days = int(req, "days", 1)
        price = tariff[:days][days] or return error("UNDEFINED_DAYS")
        return error("WARNING_LOW_BALANCE") if state.available < State.to_mills(price)

        state.balance -= State.to_mills(price)
        rent.days += days
        rent.sum = State.from_mills(State.to_mills(rent.sum) + State.to_mills(price))
        { "response" => 1, "item" => rent_item(state, rent, req) }
      end

      def close_rent_num(state, req)
        tzid = int(req, "tzid", 0)
        return error("ERROR_WRONG_TZID") unless state.rents.delete(tzid)

        state.scheduled.delete(tzid)
        { "response" => "1" }
      end

      def rent_tariff(state, code)
        tariff = state.rent_tariffs[code] or return []
        count = tariff[:days].keys.to_h { |d| [d, 100] }
        { "code" => code, "enabled" => true, "name" => country_name(code).first, "new" => false, "position" => code,
          "count" => count, "days" => tariff[:days].dup, "extend" => tariff[:extend], "confirm" => false,
          "ext_counts" => count }
      end

      def tariffs_rent(state, req)
        return rent_tariff(state, int(req, "country", 0)) unless req[:query]["country"].nil?

        all = state.rent_tariffs.keys.to_h { |code| [code, rent_tariff(state, code)] }
        all.empty? ? [] : all
      end

      # ----- user -----

      def get_balance(state, req)
        res = { "response" => "1", "balance" => decimal(state.balance), "zbalance" => State.from_mills(state.frozen) }
        res.merge!("income" => 0, "income_usd" => "0.000") unless req[:query]["income"].nil?
        res
      end

      def get_profile(state, _req)
        { "response" => "1", "profile" => PROFILE.merge("apikey" => state.api_key, "webhook_url" => state.webhook_url) }
      end

      def http_url?(value)
        uri = URI.parse(value)
        %w[http https].include?(uri.scheme) && !uri.host.to_s.empty?
      rescue URI::InvalidURIError
        false
      end

      def profile(state, req)
        body = req[:body]
        return error("ERROR_PARAMS") unless req[:method] == "POST" && body.is_a?(Hash) && body["profile"].is_a?(Hash)

        fields = body["profile"]
        url = fields["webhook_url"]
        unless url.nil? || (url.is_a?(String) && http_url?(url))
          return { "response" => { "webhook_url" => ["The webhook url must be a valid URL."] } }
        end

        state.webhook_url = url if fields.key?("webhook_url")
        { "response" => "1", "user" => { "id" => State::USER_ID, "webhook_url" => state.webhook_url } }
      end

      def webhook_logs(state, req)
        { "response" => "1", "data" => paginate(state.webhook_logs.reverse, int(req, "page", 1), 10, "webhook-logs") }
      end

      def get_payment_history(_state, req)
        { "response" => "1", "orders" => paginate([], int(req, "page", 1), 10, "getPaymentHistory.php"),
          "paylist" => [], "domains" => [], "currency" => { "USD" => 1 } }
      end

      # ----- free -----

      def get_free_list(_state, req) # rubocop:disable Metrics/AbcSize
        wanted = int(req, "country", 44)
        country = FREE.key?(wanted) ? wanted : FREE.keys.first
        data = FREE[country]
        numbers = data[:numbers].keys.to_h do |n|
          [n, { "country" => country, "country_original" => data[:name], "data_humans" => "1 day ago",
                "full_number" => "#{country}#{n}", "is_archive" => false }]
        end
        number = data[:numbers].key?(req[:query]["number"]) ? req[:query]["number"] : data[:numbers].keys.first
        messages = data[:numbers][number].each_with_index.map do |(sender, text), i|
          { "id" => i + 1, "text" => text, "in_number" => sender, "my_number" => number, "created_at" => State.stamp(i),
            "data_humans" => "1 day ago", "code" => State.extract_code(text) || "-" }
        end
        page = paginate(messages, int(req, "page", 1), int(req, "count", 10), "getFreeList")
        {
          "response" => 1,
          "countries" => FREE.map { |c, d| { "country" => c, "country_text" => d[:text], "country_original" => d[:name] } },
          "numbers" => numbers,
          "messages" => page.merge("number" => number, "country" => country)
        }
      end

      ROUTES = {
        "getPrice.php" => :get_price,
        "getNum.php" => :get_num,
        "getState.php" => :get_state,
        "setOperationRevise.php" => :set_operation_revise,
        "setOperationOk.php" => :set_operation_ok,
        "getNumbersStats.php" => :get_numbers_stats,
        "rent/getRentNum.php" => :get_rent_num,
        "rent/getRentState.php" => :get_rent_state,
        "rent/extendRentState.php" => :extend_rent_state,
        "rent/closeRentNum.php" => :close_rent_num,
        "rent/tariffsRent.php" => :tariffs_rent,
        "getBalance.php" => :get_balance,
        "getProfile.php" => :get_profile,
        "profile.php" => :profile,
        "webhook-logs" => :webhook_logs,
        "getPaymentHistory.php" => :get_payment_history,
        "getFreeList" => :get_free_list
      }.freeze
    end
  end
end
