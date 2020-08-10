module OnlineSim
  class BaseError < RuntimeError
  end

  class ServerError < BaseError
    def initialize(msg = 'Server error') super(msg); end
  end

  class ApiError < BaseError
    def initialize(msg = 'Api error') super(msg); end
  end
end
