require 'onlinesim/Base'

module OnlineSim
  class GetProxy < Base
    def get(cl:'days', type:'private', connect:'https', count: 1, operator:nil, country: 7, city: 'any', port_count: 1, session:true )
      return self ._get(:endpoint => '/proxy/getProxy', :params => {cl: cl,type:type,connect:connect,count:count,operator:operator,country:country,city:city,port_count:port_count,session:session})['item']
    end

    def state(orderby: "ASC")
      return self ._get(:endpoint => '/proxy/getState', :params => {orderby: orderby})['list']
    end

    def stateone(tzid)
      return self ._get(:endpoint => '/proxy/getState', :params => {tzid: tzid})['list'][0]
    end

    def changeip(tzid)
      return self ._get(:endpoint => '/proxy/changeIp', :params => {tzid: tzid})
    end

    def changetype(tzid)
      return self ._get(:endpoint => '/proxy/changeType', :params => {tzid: tzid})['connect_type']
    end

    def setcomment(tzid, comment: '')
      return self ._get(:endpoint => '/proxy/setComment', :params => {tzid: tzid,comment:comment})
    end
  end
end