---
title: Webhooks
description: Receive SMS as HTTP callbacks and parse them with OnlineSim.parse_webhook.
navigation:
  order: 5
---

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

| Field | Type | Description |
|---|---|---|
| `webhook_type` | `"receiving_sms"`, `"rent_sms"`, `nil` | Kind of operation. |
| `operation_id` | `Integer`, `nil` | `tzid` of the operation or rent. |
| `user_id` | `Integer`, `nil` | Account id. |
| `country_code` | `Integer`, `nil` | Country code of the number. |
| `number` | `String`, `nil` | The number, e.g. `+79001234567`. |
| `sender` | `String`, `nil` | Sender of the SMS, e.g. `VK`. |
| `message` | `String`, `nil` | Full SMS text. |
| `code` | `String`, `nil` | Code extracted from the SMS. |
| `time_start` | `String`, `nil` | Start of the operation. |
| `time_left` | `Integer`, `nil` | Time left. |
