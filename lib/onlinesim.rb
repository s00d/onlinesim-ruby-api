require 'onlinesim/GetFree'
require 'onlinesim/GetForward'
require 'onlinesim/GetNumbers'
require 'onlinesim/GetProxy'
require 'onlinesim/GetRent'
require 'onlinesim/GetUser'

module OnlineSim
  class Driver
    def initialize(apikey: '', lang: 'en', dev_id: str = nil)
      @apikey = apikey
      @lang = lang
      @dev_id = dev_id
    end

    def numbers
      OnlineSim::GetNumbers.new(:apikey => @apikey, :lang => @lang, :dev_id => @dev_id)
    end

    def forward
      OnlineSim::GetForward.new(:apikey => @apikey, :lang => @lang, :dev_id => @dev_id)
    end

    def free
      OnlineSim::GetFree.new(:apikey => @apikey, :lang => @lang, :dev_id => @dev_id)
    end

    def proxy
      OnlineSim::GetProxy.new(:apikey => @apikey, :lang => @lang, :dev_id => @dev_id)
    end

    def rent
      OnlineSim::GetRent.new(:apikey => @apikey, :lang => @lang, :dev_id => @dev_id)
    end

    def user
      OnlineSim::GetUser.new(:apikey => @apikey, :lang => @lang, :dev_id => @dev_id)
    end
  end
end