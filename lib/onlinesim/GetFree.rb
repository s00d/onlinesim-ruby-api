require 'onlinesim/base'

module OnlineSim
  class GetFree < Base
    def countries
      return self ._get(:endpoint => 'getFreeCountryList')['countries']
    end

    def numbers(country: 7)
      return self ._get(:endpoint => 'getFreePhoneList', :params => {country: country})['numbers']
    end

    def messages(phone, page: 1)
      return self ._get(:endpoint => 'getFreeMessageList', :params => {phone: phone, page: page})['messages']['data']
    end
  end
end