# frozen_string_literal: true

module OnlineSim
  # Public free numbers: `client.free`. No key needed.
  class Free
    def initialize(request)
      @request = request
    end

    # Countries, the numbers of the selected country and the SMS of the selected number.
    # `number` is the number without its country code, as the keys of "numbers".
    def list(country: nil, number: nil, page: nil, count: nil)
      res = @request.call("getFreeList", query: { country: country, number: number, page: page, count: count })
      { "countries" => res["countries"], "numbers" => Normalize.map(res["numbers"]), "messages" => res["messages"] }
    end
  end
end
