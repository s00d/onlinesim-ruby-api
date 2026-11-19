# frozen_string_literal: true

module OnlineSim
  # Numbers for receiving SMS: `client.numbers`. Results are Hashes with the server's (string) keys.
  class Numbers
    def initialize(request)
      @request = request
    end

    # Price (USD) of one number of `service` in `country`; nil when the country has no price for it.
    def price(service, country = 7)
      @request.call("getPrice.php", query: { service: service, country: country })["price"]
    end

    # Order a number. Returns the operation id (tzid).
    def get(service, country = 7, reject: nil)
      @request.call("getNum.php", query: { service: service, country: country, reject: reject })["tzid"]
    end

    # Order a number and get it right away: {"tzid", "number", "country", "time", "service", ...}.
    def get_with_number(service, country = 7, reject: nil)
      # `number` is a presence flag on getNum: sent here only.
      @request.call("getNum.php", query: { service: service, country: country, reject: reject, number: 1 })
    end

    # All operations of the account; [] when there are none.
    def state(message_to_code: true, order_by: "asc", msg_list: false)
      @request.call("getState.php", query: {
                      message_to_code: message_to_code, orderby: order_by, msg_list: msg_list, number: 1
                    })
    rescue ApiError => e
      raise unless e.code == "ERROR_NO_OPERATIONS"

      []
    end

    # One operation. Raises ApiError ERROR_NO_OPERATIONS when it does not exist (any more).
    def state_one(tzid, message_to_code: true, msg_list: false)
      list = @request.call("getState.php", query: {
                             tzid: tzid, message_to_code: message_to_code, msg_list: msg_list, number: 1
                           })
      list.first || raise(ApiError, "ERROR_NO_OPERATIONS")
    end

    # Switch the operation to its next SMS and keep it open.
    def next(tzid)
      @request.call("setOperationRevise.php", query: { tzid: tzid })
      true
    end

    # Finish the operation.
    def close(tzid)
      @request.call("setOperationOk.php", query: { tzid: tzid })
      true
    end

    # Finish the operation and report the number as bad (only before any SMS arrived).
    def ban(tzid)
      @request.call("setOperationOk.php", query: { tzid: tzid, ban: true })
      true
    end

    # Services, prices and stock of every country, keyed by country code. No key needed.
    def tariffs
      Normalize.map(@request.call("getNumbersStats.php", query: { country: "all" }))
               .transform_values { |c| country(c) }
    end

    # Services, prices and stock of one country. No key needed.
    def tariffs_one(code = 7)
      country(@request.call("getNumbersStats.php", query: { country: code }))
    end

    # Poll the operation until an SMS code arrives, then close it (or `next` with keep_open). See OnlineSim.wait_code.
    def wait_code(tzid, **options)
      OnlineSim.wait_code(self, tzid, **options)
    end

    private

    def country(stat)
      stat.merge("services" => Normalize.map(stat["services"]))
    end
  end
end
