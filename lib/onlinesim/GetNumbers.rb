require 'onlinesim/Base'

module OnlineSim
  class GetNumbers < Base
    def price(service)
      return self ._get(:endpoint => 'getPrice', :params => {service:service})['price']
    end

    def get(service, country: 7, reject: nil, extension: false)
      return self ._get(:endpoint => 'getNum', :params => {service:service,country:country,reject:reject,extension:extension})['tzid']
    end

    def state(message_to_code:1, orderby: 'ASC', msg_list:true, clean: false, repeat:false)
      type = 'index'
      if repeat
        type = 'repeat'
      end
      return self ._get(:endpoint => 'getState', :params => {message_to_code:message_to_code,orderby:orderby,msg_list:msg_list,clean:clean,type:type})
    end

    def stateone(tzid, message_to_code = 1, msg_list = true, clean = false, repeat =false)
      type = 'index'
      if repeat
        type = 'repeat'
      end
      return self ._get(:endpoint => 'getState', :params => {tzid:tzid,message_to_code:message_to_code,msg_list:msg_list,clean:clean,type:type})[0]
    end

    def next(tzid)
      return self ._get(:endpoint => 'setOperationRevise', :params => {tzid:tzid})
    end

    def close(tzid)
      return self ._get(:endpoint => 'setOperationOk', :params => {tzid:tzid})
    end

    def ban(tzid)
      return self ._get(:endpoint => 'setOperationOk', :params => {tzid:tzid, ban: 1})
    end

    def tariffs()
      return self ._get(:endpoint => 'getNumbersStats', :params => {country:'all'})
    end

    def tariffsone(country:7)
      return self ._get(:endpoint => 'getNumbersStats', :params => {country:country})
    end

    def service()
      return self ._get(:endpoint => 'getService')['service']
    end

    def servicenumber(service)
      return self ._get(:endpoint => 'getServiceNumber', :params => {service:service})['number']
    end

    def wait_code(tzid, timeout = 10, not_end = false)
      __last_code = ''
      counter = 0
      while true
        sleep(timeout)
        counter += 1
        if counter >= 10
          raise ApiError, "Timeout error"
        end
        response = self.stateone(tzid,1, false)
        begin  # "try" block
          if !not_end and response['msg'] != __last_code
            __last_code = response['msg']
            self.close(tzid)
            break
          end
          if not_end and response['msg'] != __last_code
            __last_code = response['msg']
            self.next(tzid)
            break
          end
        rescue
        end

      end

      return __last_code
    end
  end
end