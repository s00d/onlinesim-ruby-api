---
title: User
description: Balance, profile, payments and the webhook URL — client.user.
navigation:
  order: 3
---

## balance

Balance in USD.

```ruby
balance # => {"balance" => Float, "zbalance" => Float, "income" => Float (when sent)}
```

`balance` includes the sum frozen by numbers in progress (`zbalance`): available = `balance − zbalance`. `income` is the partner income. The server caches the answer for 60 s.

```ruby
b = client.user.balance
available = b["balance"] - b["zbalance"]
```

Errors: `ApiError` `ERROR_WRONG_KEY`, `ACCOUNT_BLOCKED`, `API_ACCESS_DISABLED`, `API_ACCESS_IP`.

## profile

The account profile.

```ruby
profile # => Hash
```

Profile: `{"id", "name", "username", "email", "locale", "currency", "number_country", "number_reject", "webhook_url", "api_access", …}`.

```ruby
profile = client.user.profile
puts profile.values_at("email", "webhook_url").join(" ")
```

## payment_history

Top-up orders (paginated, newest first) and the available payment methods.

```ruby
payment_history(page = 1) # => Hash
```

`{"orders" => paginator, "paylist", "domains"?, "forms"?, "currency"?, "buttons"?}`. An order's `sum` stays a decimal string (`"89.00"`).

```ruby
orders = client.user.payment_history["orders"]
puts "#{orders['total']} orders, page #{orders['current_page']}/#{orders['last_page']}"
```

## set_webhook_url

Set the URL that receives SMS webhooks (see [Webhooks](/webhooks)).

```ruby
set_webhook_url(url) # => true
```

```ruby
client.user.set_webhook_url("https://example.com/onlinesim-hook")
```

Errors: `ApiError` `VALIDATION_ERROR` for an invalid URL; `message` holds the server's field messages.

## clear_webhook_url

Remove the webhook URL, also from operations in progress.

```ruby
clear_webhook_url # => true
```

```ruby
client.user.clear_webhook_url
```

## webhook_logs

Webhook delivery log, newest first, 10 per page.

```ruby
webhook_logs(page = 1) # => paginator Hash
```

A log entry: `{"id", "user_id", "webhook_url", "type", "params", "status", "error", "created_at", "updated_at"}` — `type` is `receiving_sms` or `rent_sms`, `status` is `success`, `fail` or `pending`, `params` the payload that was sent.

```ruby
client.user.webhook_logs["data"].each do |log|
  puts log.values_at("created_at", "status", "error").join(" ")
end
```
