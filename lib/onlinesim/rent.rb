# frozen_string_literal: true

module OnlineSim
  # Rented numbers: `client.rent`.
  class Rent
    # Always sent: flat `messages` list and `time_seconds`.
    DETAIL = { pagination: 0, number: 1 }.freeze

    def initialize(request)
      @request = request
    end

    # Rent a number for `days` days. The price is reserved (`status` 0); the first SMS that is not `notify`
    # confirms the rent and charges it. `extension: false` makes the rent non-extendable for good.
    def get(country = 7, days = 1, extension: true)
      res = @request.call("rent/getRentNum.php", query: { country: country, days: days, extension: extension, **DETAIL })
      item(res["item"])
    end

    # All rents of the account.
    def state
      @request.call("rent/getRentState.php", query: DETAIL)["list"].map { |raw| item(raw) }
    end

    # One rent. Raises ApiError ERROR_NO_OPERATIONS when it does not exist.
    def state_one(tzid)
      raw = @request.call("rent/getRentState.php", query: { tzid: tzid, **DETAIL })["list"].first
      raise ApiError, "ERROR_NO_OPERATIONS" unless raw

      item(raw)
    end

    # Extend a rent by `days` days and charge at once (only confirmed rents created with `extension: true`).
    # Overrides Object#extend on this section object on purpose: the name is the API's.
    def extend(tzid, days = 1)
      item(@request.call("rent/extendRentState.php", query: { tzid: tzid, days: days, **DETAIL })["item"])
    end

    # Rent prices of every country, keyed by country code. No key needed.
    def tariffs
      Normalize.map(@request.call("rent/tariffsRent.php"))
    end

    # Rent prices of one country. Raises ApiError NO_COUNTRY for a country without rent. No key needed.
    def tariffs_one(country = 7)
      res = @request.call("rent/tariffsRent.php", query: { country: country })
      # An unknown country answers `[]`.
      raise ApiError, "NO_COUNTRY" unless res.is_a?(Hash) && res.key?("code")

      res
    end

    # Return the number before the rent period ends.
    def close(tzid)
      @request.call("rent/closeRentNum.php", query: { tzid: tzid })
      true
    end

    private

    # `sum` is a number (getRentNum, extendRentState) or a decimal string (getRentState), `extend` may be `[]`.
    # Message `code` stays as sent: a String, or the Integer 0 for a `notify` SMS.
    def item(raw)
      raw.merge(
        "sum" => (Normalize.num(raw["sum"]) || 0).to_f,
        "extend" => Normalize.map(raw["extend"]),
        "messages" => raw["messages"].is_a?(Array) ? raw["messages"] : []
      )
    end
  end
end
