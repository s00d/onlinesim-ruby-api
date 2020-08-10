require 'onlinesim/Base'

module OnlineSim
  class GetUser < Base
    def balance
      return self ._get(:endpoint => 'getBalance', :params => {income: true})
    end

    def profile
      return self ._get(:endpoint => 'getProfile')['profile']
    end
  end
end