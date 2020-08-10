require 'faraday'
require 'oj'
require 'onlinesim/error'

module FaradayOverrides
  def initialize *args
    options = args.last
    options[:ssl] = {verify: false}
    super
  end
end

module OnlineSim
  class Base
    HTTP_OK_CODE = 200

    def initialize(apikey: nil, lang: 'en', dev_id: nil)
      @apikey = apikey
      @lang = lang
      @dev_id = dev_id

      Faraday.ignore_env_proxy = true
      Faraday::Connection.prepend FaradayOverrides
    end

    private
    def client
      @_client ||= Faraday.new('https://onlinesim.ru', proxy: 'http://127.0.0.1:4034') do |client|
        client.request :url_encoded
        client.adapter Faraday.default_adapter
        client.headers['User-agent'] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/84.0.4147.89 Safari/537.36"
      end
    end

    protected
    def _get(endpoint: '', params: {})
      params['apikey'] = @apikey
      params['lang'] = @lang
      params['dev_id'] = @dev_id
      if @dev_id
        params['dev_id'] = @dev_id
      end
      resp = client.public_send("get", '/api/' + endpoint + '.php', params)

      parsed_response = Oj.load(resp.body)

      if resp.status == HTTP_OK_CODE
        def valid_json?(parsed_response)
          puts parsed_response['response']
          if parsed_response.key?('response') and parsed_response['response'].to_s != '1'
            raise ApiError, parsed_response['response']
          end
          if parsed_response.key?('response')
            parsed_response.delete('response')
          end
        rescue JSON::ParserError
        end
        return parsed_response
      end

      raise ApiError, "Code: #{resp.status}, response: #{resp.body}"
    end

  end
end
