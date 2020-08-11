require 'onlinesim/Base'

module OnlineSim
  class GetRent < Base
    def get(country: 7, days: 1, extension: false)
      return self._get(:endpoint => '/rent/getRentNum', :params => {country: country,days:days,extension:extension})['item']
    end

    def state
      return self._get(:endpoint => '/rent/getRentState', :params => {pagination: false})['list']
    end

    def stateone(tzid)
      return self._get(:endpoint => '/rent/getRentState', :params => {tzid:tzid, pagination: false})['list'][0]
    end

    def extend(tzid)
      return self._get(:endpoint => '/rent/extendRentState', :params => {tzid:tzid})
    end

    def tariffs
      return self._get(:endpoint => '/rent/tariffsRent')
    end

    def tariffsone(country: 7)
      return self._get(:endpoint => '/rent/tariffsRent', :params => {country:country})
    end

    def close(tzid)
      return self._get(:endpoint => '/rent/closeRentNum', :params => {tzid:tzid})
    end
  end
end