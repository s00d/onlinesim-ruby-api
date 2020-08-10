require 'onlinesim/Base'

module OnlineSim
  class GetForward < Base
    def get(forward_numbers: [], service: 'unlimited_sms', region: nil, reject: [])
      return self ._get(:endpoint => 'getForward', :params => {forward_numbers:forward_numbers, service:service,region:region,reject: reject})['tzid']
    end

    def state(message_to_code: 1, orderby: 'ASC', msg_list: true, clean: true)
      return self ._get(:endpoint => 'getState', :params => {message_to_code:message_to_code, orderby:orderby,msg_list:msg_list,clean: clean, type:'forward'})
    end

    def stateone(tzid, message_to_code: 1, orderby: 'ASC', msg_list: true, clean: true)
      return self ._get(:endpoint => 'getState', :params => {tzid:tzid,message_to_code:message_to_code, orderby:orderby,msg_list:msg_list,clean: clean, type:'forward'})
    end

    def close(tzid)
      return self ._get(:endpoint => 'setOperationOk', :params => {tzid:tzid})
    end

    def repeat(service, number)
      return self ._get(:endpoint => 'getNumRepeat', :params => {service:service, number:number})['tzid']
    end

    def tariffs()
      return self ._get(:endpoint => 'getNumbersStats', :params => {country:'all'})
    end

    def tariffsone(country: 7)
      return self ._get(:endpoint => 'getNumbersStats', :params => {country:country})
    end

    def service()
      return self ._get(:endpoint => 'getService')['service']
    end

    def servicenumber(service)
      return self ._get(:endpoint => 'getServiceNumber', :params => {service:service})['number']
    end
  end
end