---
title: onlinesim-ruby-api
description: Zero-dependency Ruby client for the OnlineSim API — SMS numbers, rent, account and free numbers.
---

## Install

Ruby 3.0 or newer. No runtime dependencies: the client uses `Net::HTTP` and `JSON` from the standard library.

::code-group
```bash [bundler]
bundle add onlinesim
```

```bash [gem]
gem install onlinesim
```
::

## Quick start

Check the balance, order a number, wait for the SMS code.

```ruby
require "onlinesim"

client = OnlineSim::Client.new(api_key: ENV["ONLINESIM_KEY"])

balance = client.user.balance
puts "available: #{balance['balance'] - [balance['zbalance'], 0].max} USD"

order = client.numbers.get_with_number("google", 44)
puts "enter #{order['number']} in the app"

# Polls every 5 s for up to 10 min, then closes the operation.
code = client.numbers.wait_code(order["tzid"])
puts "code: #{code}"
```

## Client options

```ruby
client = OnlineSim::Client.new(
  api_key: "your-api-key",
  lang: "en",
  timeout: 15
)
```

| Option | Type | Default | Description |
|---|---|---|---|
| `api_key` | `String` | — | Sent as `Authorization: Bearer <api_key>`, never in the URL. Not needed for tariffs and free numbers. |
| `base_url` | `String` | `https://onlinesim.host/api/` | API base; trailing slash optional. |
| `lang` | `String` | `"en"` | Language of server texts (`lang` query parameter). |
| `dev_id` | `String`, `Integer` | — | Partner developer id (`dev_id`), sent only when set. |
| `timeout` | `Numeric` | `30` | Per-request timeout, **seconds** (connect, read and write each). |
| `transport` | object | `OnlineSim::NetHttpTransport.new` | Anything with `call(method, url, headers, body, timeout)` returning `[status, body]`: a proxy setup, custom TLS, or a fake in tests. |

`NetHttpTransport.new(**options)` passes `options` to `Net::HTTP.start` (`ca_file:`, `cert:`, `key:`, …). TLS is verified by default; the proxy comes from `http_proxy` / `https_proxy` / `no_proxy`.

Sections: [`client.numbers`](/numbers), [`client.rent`](/rent), [`client.user`](/user), [`client.free`](/free). Webhook bodies are parsed by the module function [`OnlineSim.parse_webhook`](/webhooks).

Results are plain `Hash`/`Array` values with the server's string keys (`order["tzid"]`). Two things are normalised: money that the server sends as a decimal string (`balance`, rent `sum` in `rent.state`) becomes a `Float`, and maps that arrive as an empty PHP array `[]` become `{}`. `payment_history["paylist"]` is left as sent: an `Array` when its ids are 0, 1, 2… Durations (`timeout`, `interval`) are seconds.

## Error handling

Every error is an `OnlineSim::Error` (a `StandardError`).

| Class | When | Attributes |
|---|---|---|
| `ApiError` | The API answered with an error code (also a wrong key, HTTP 456, and the rate limit, HTTP 429 `TRY_AGAIN_LATER`). | `code`, `message` |
| `NoNumberError` | `NO_NUMBER`: no number right now. Subclass of `ApiError`. | `code`, `message` |
| `TransportError` | Network error, request timeout, or a body that is not JSON. | `status` (`nil` without a response), `body` (first 500 chars) |
| `TimeoutError` | `wait_code` got no code within its `timeout`. | — |

```ruby
begin
  client.numbers.get("google", 44)
rescue OnlineSim::NoNumberError
  # try another country or later
rescue OnlineSim::ApiError => e
  warn "#{e.code}: #{e.message}" # e.g. WARNING_LOW_BALANCE
rescue OnlineSim::TransportError => e
  warn "network: #{e.status} #{e.body}"
end
```

`message` is the server's text when it sends one, otherwise a short English description of the code (`OnlineSim::ERROR_MESSAGES`), otherwise the code itself. Profile validation failures become `ApiError` with code `VALIDATION_ERROR`.
