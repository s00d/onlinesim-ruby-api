---
title: Numbers
description: Order a number, read its SMS, close it — client.numbers.
navigation:
  order: 1
---

An operation (`tzid`) is one ordered number. Order it with `get`/`get_with_number`, read the SMS with `state_one` or `wait_code`, finish it with `close` (or `ban`). Countries are phone codes (`7`, `44`, …), services are slugs (`google`, `vkcom`, …) as returned by `tariffs`.

## price

Price of one number, USD; `nil` when the country has no price for the service.

```ruby
price(service, country = 7) # => Float or nil
```

| Param | Type | Default | Description |
|---|---|---|---|
| `service` | `String` | — | Service slug. |
| `country` | `Integer` | `7` | Country code. |

```ruby
usd = client.numbers.price("google", 44)
```

Errors: `ApiError` `ERROR_NO_SERVICE`, `UNDEFINED_COUNTRY`.

## get

Order a number; returns the operation id. Freezes the price on the balance.

```ruby
get(service, country = 7, reject: nil) # => Integer (tzid)
```

| Param | Type | Default | Description |
|---|---|---|---|
| `service` | `String` | — | Service slug. |
| `country` | `Integer` | `7` | Country code. |
| `reject:` | `Array` | profile list | Number prefixes to skip, e.g. `["4470"]`. |

```ruby
tzid = client.numbers.get("google", 44, reject: ["4470"])
```

Errors: `NoNumberError`; `ApiError` `WARNING_LOW_BALANCE`, `ERROR_NO_SERVICE`, `UNDEFINED_COUNTRY`, `EXCEEDED_CONCURRENT_OPERATIONS`, `INTERVAL_CONCURRENT_REQUESTS_ERROR`, `TRY_AGAIN_LATER`.

## get_with_number

Same as `get`, but returns the number right away.

```ruby
get_with_number(service, country = 7, reject: nil) # => Hash
```

Returns `{"tzid", "number", "country", "time", "service", "title"?, "guard_interval_remaining_seconds"?}` — `number` with `+`, `time` in seconds left.

```ruby
order = client.numbers.get_with_number("google", 44)
puts order["number"]
```

Errors: as `get`.

## state

All operations of the account; `[]` when there are none.

```ruby
state(message_to_code: true, order_by: "asc", msg_list: false) # => Array of Hash
```

| Option | Type | Default | Description |
|---|---|---|---|
| `message_to_code:` | `Boolean` | `true` | `msg` is the code only; `false` — the full SMS text. |
| `order_by:` | `"asc"`, `"desc"` | `"asc"` | Order of operations. |
| `msg_list:` | `Boolean` | `false` | `msg` is a list of all SMS (`[{"service", "msg"}]`). |

An operation: `{"tzid", "response", "number"?, "service"?, "country"?, "sum"?, "time"?, "msg"?, "guard_interval_remaining_seconds"?, …}`.
`response` is the state: `TZ_INPOOL` (number being assigned), `TZ_NUM_WAIT` (waiting for SMS), `TZ_NUM_ANSWER` (SMS arrived), `TZ_OVER_OK` (finished), `ERROR_NO_ITEMS` (failed). `msg` is absent until the first SMS. The server caches answers for a few seconds.

```ruby
client.numbers.state(order_by: "desc").each do |op|
  puts [op["tzid"], op["response"], op["msg"]].join(" ")
end
```

## state_one

One operation.

```ruby
state_one(tzid, message_to_code: true, msg_list: false) # => Hash
```

```ruby
op = client.numbers.state_one(tzid)
puts op["msg"] if op["response"] == "TZ_NUM_ANSWER"
```

Errors: `ApiError` `ERROR_NO_OPERATIONS` when the operation does not exist (any more).

## wait_code

Poll the operation until a code arrives, then close it and return the code.

```ruby
wait_code(tzid, interval: 5, timeout: 600, keep_open: false, full_message: false, since: nil) # => String
```

| Option | Type | Default | Description |
|---|---|---|---|
| `interval:` | `Numeric` | `5` | Poll interval, seconds. |
| `timeout:` | `Numeric` | `600` | Give up after, seconds. |
| `keep_open:` | `Boolean` | `false` | Call `next(tzid)` instead of `close(tzid)`, to wait for another SMS. |
| `full_message:` | `Boolean` | `false` | Return the full SMS text instead of the code. |
| `since:` | `String`, `nil` | `nil` | Ignore this value (the previous code). |
| `sleep:`, `now:` | callables | `Kernel#sleep`, monotonic clock | Injectable for tests (seconds). |

A transient `TransportError` is retried until the timeout; any `ApiError` is raised at once. Also available as `OnlineSim.wait_code(numbers, tzid, **options)`.

```ruby
first = client.numbers.wait_code(tzid, keep_open: true)
second = client.numbers.wait_code(tzid, since: first)
```

Errors: `TimeoutError`; `ApiError` with code `TZ_OVER_OK` or `ERROR_NO_ITEMS` when the operation ended without a new code; any other `ApiError` from `state_one`/`close`/`next`.

## next

Switch the operation to its next SMS and keep it open (for services that send several SMS).

```ruby
next(tzid) # => true
```

```ruby
client.numbers.next(tzid)
```

## close

Finish the operation. An operation without SMS can be closed only after its guard interval (`guard_interval_remaining_seconds`); every attempt locks the tzid for 5 s.

```ruby
close(tzid) # => true
```

```ruby
client.numbers.close(tzid)
```

Errors: `ApiError` `NO_COMPLETE_TZID`, `INTERVAL_CONCURRENT_REQUESTS_ERROR`, `ERROR_WRONG_TZID`.

## ban

Finish the operation and report the number as bad. Only before any SMS arrived.

```ruby
ban(tzid) # => true
```

```ruby
client.numbers.ban(tzid)
```

Errors: as `close`.

## tariffs

Services, prices and stock of every country, keyed by country code (a `String`). No API key needed. The answer is large (a few MB); prefer `tariffs_one`.

```ruby
tariffs # => Hash of country code => Hash
```

A country: `{"name", "locale_name"?, "position", "code", "other"?, "new", "enabled", "services"}`; `services` maps `service_<slug>` to `{"count", "popular", "code", "price", "id", "service", "slug"}`.

```ruby
all = client.numbers.tariffs
puts "#{all.size} countries"
```

## tariffs_one

Services, prices and stock of one country.

```ruby
tariffs_one(country = 7) # => Hash
```

```ruby
uk = client.numbers.tariffs_one(44)
uk["services"].each_value { |s| puts [s["slug"], s["price"], s["count"]].join(" ") }
```

Errors: `ApiError` `NO_COUNTRY`.
