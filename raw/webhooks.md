# Webhooks

> Receive SMS as HTTP callbacks and parse them with OnlineSim.parse_webhook.

Set a URL with [`client.user.set_webhook_url`](/user#set_webhook_url). For each SMS the server POSTs a JSON body to it: `webhook_type` `receiving_sms` for numbers, `rent_sms` for rents. Delivery attempts are listed by [`client.user.webhook_logs`](/user#webhook_logs).

## parse_webhook

Parse an inbound webhook body from a JSON string or an already parsed `Hash` (string or symbol keys).

```ruby
OnlineSim.parse_webhook(payload) # => Hash
```

Lenient: numeric fields may arrive as strings, missing or malformed fields become `nil`, unknown fields are dropped. It raises `OnlineSim::Error` only when the input is not a JSON object.

```ruby
require "onlinesim"

# Rack app (config.ru): run WebhookApp
WebhookApp = lambda do |env|
  hook = OnlineSim.parse_webhook(env["rack.input"].read)
  puts "#{hook['operation_id']} #{hook['code']}" if hook["webhook_type"] == "receiving_sms"
  [200, { "content-type" => "text/plain" }, ["ok"]]
end
```

## Payload fields

<table>
<thead>
  <tr>
    <th>
      Field
    </th>
    
    <th>
      Type
    </th>
    
    <th>
      Description
    </th>
  </tr>
</thead>

<tbody>
  <tr>
    <td>
      <code>
        webhook_type
      </code>
    </td>
    
    <td>
      <code>
        "receiving_sms"
      </code>
      
      , <code>
        "rent_sms"
      </code>
      
      , <code>
        nil
      </code>
    </td>
    
    <td>
      Kind of operation.
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        operation_id
      </code>
    </td>
    
    <td>
      <code>
        Integer
      </code>
      
      , <code>
        nil
      </code>
    </td>
    
    <td>
      <code>
        tzid
      </code>
      
       of the operation or rent.
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        user_id
      </code>
    </td>
    
    <td>
      <code>
        Integer
      </code>
      
      , <code>
        nil
      </code>
    </td>
    
    <td>
      Account id.
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        country_code
      </code>
    </td>
    
    <td>
      <code>
        Integer
      </code>
      
      , <code>
        nil
      </code>
    </td>
    
    <td>
      Country code of the number.
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        number
      </code>
    </td>
    
    <td>
      <code>
        String
      </code>
      
      , <code>
        nil
      </code>
    </td>
    
    <td>
      Numbers: <code>
        +
      </code>
      
       and the full number (<code>
        +79001234567
      </code>
      
      ), or <code>
        hidden
      </code>
      
      . Rent: the full number in digits without <code>
        +
      </code>
      
       (<code>
        79001234567
      </code>
      
      ).
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        sender
      </code>
    </td>
    
    <td>
      <code>
        String
      </code>
      
      , <code>
        nil
      </code>
    </td>
    
    <td>
      Sender of the SMS, e.g. <code>
        VK
      </code>
      
      .
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        message
      </code>
    </td>
    
    <td>
      <code>
        String
      </code>
      
      , <code>
        nil
      </code>
    </td>
    
    <td>
      Full SMS text.
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        code
      </code>
    </td>
    
    <td>
      <code>
        String
      </code>
      
      , <code>
        nil
      </code>
    </td>
    
    <td>
      Code extracted from the SMS; <code>
        ""
      </code>
      
       when none was found.
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        time_start
      </code>
    </td>
    
    <td>
      <code>
        String
      </code>
      
      , <code>
        nil
      </code>
    </td>
    
    <td>
      Numbers: when the operation was ordered. Rent: when the SMS arrived. <code>
        YYYY-MM-DD HH:MM:SS
      </code>
      
      .
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        time_left
      </code>
    </td>
    
    <td>
      <code>
        Integer
      </code>
      
      , <code>
        nil
      </code>
    </td>
    
    <td>
      Time left: seconds for numbers, minutes for rent.
    </td>
  </tr>
</tbody>
</table>
