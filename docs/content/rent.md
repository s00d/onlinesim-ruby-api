---
title: Rent
description: Rent a number for days and receive every SMS sent to it — client.rent.
navigation:
  order: 2
---

A rent keeps a number for `days` days. Its SMS come in `"messages"`, newest first.

A rent item: `{"tzid", "status", "number", "country", "sum", "days", "hours", "time", "time_seconds"?, "extension", "extend", "messages", "start_time", "stop_time", "day_extend"?, …}` —
`sum` is the price paid in USD (a `Float`; the server sends a decimal string), `time` minutes left, `time_seconds` seconds left,
`extension` `0` not extendable / `1` extendable / `2` auto-extension, `extend` maps days to the extension price (`{}` when not extendable),
`messages` is a list of `{"id", "service", "text", "code", "created_at"}`.

## get

Rent a number and charge the balance.

```ruby
get(country = 7, days = 1, extension: true) # => Hash
```

| Param | Type | Default | Description |
|---|---|---|---|
| `country` | `Integer` | `7` | Country code. |
| `days` | `Integer` | `1` | One of the tariff's `days` keys. |
| `extension:` | `Boolean` | `true` | `false` makes the rent non-extendable for good. |

```ruby
rent = client.rent.get(7, 7)
puts rent.values_at("tzid", "number", "sum").join(" ")
```

Errors: `NoNumberError`; `ApiError` `UNDEFINED_DAYS`, `UNDEFINED_COUNTRY`, `WARNING_LOW_BALANCE`, `INTERVAL_CONCURRENT_REQUESTS_ERROR`, `TRY_AGAIN_LATER`.

## state

All rents of the account.

```ruby
state # => Array of Hash
```

```ruby
client.rent.state.each do |rent|
  puts "#{rent['number']} #{rent['messages'].first&.fetch('code')}"
end
```

## state_one

One rent.

```ruby
state_one(tzid) # => Hash
```

```ruby
messages = client.rent.state_one(tzid)["messages"]
```

Errors: `ApiError` `ERROR_NO_OPERATIONS` for an unknown tzid.

## extend

Extend a rent by `days` days and charge the balance. Only rents created with `extension: true`.

```ruby
extend(tzid, days = 1) # => Hash
```

```ruby
rent = client.rent.extend(tzid, 3)
puts rent["stop_time"]
```

Errors: `ApiError` `TRY_AGAIN_LATER` (not extendable, unknown tzid or period, a repeat within 10 s), `WARNING_LOW_BALANCE`.

## close

Return the number before the period ends. A rent that is not confirmed yet and has no SMS can be closed only after 120 s; US numbers cannot be closed early.

```ruby
close(tzid) # => true
```

```ruby
client.rent.close(tzid)
```

Errors: `ApiError` `ERROR_NO_OPERATIONS`, `NO_COMPLETE_TZID`, `NO_CLOSE_RENT_US`, `TRY_AGAIN_LATER`.

## tariffs

Rent prices of every country, keyed by country code (a `String`). No API key needed.

```ruby
tariffs # => Hash of country code => Hash
```

A tariff: `{"code", "name", "enabled", "new", "position", "extend", "confirm"?, "days", "count", "ext_counts"?}` — `days` maps rent days to the price in USD, `count` to the numbers available.

```ruby
tariffs = client.rent.tariffs
```

## tariffs_one

Rent prices of one country.

```ruby
tariffs_one(country = 7) # => Hash
```

```ruby
days = client.rent.tariffs_one(7)["days"]
puts days["7"] # price of 7 days
```

Errors: `ApiError` `NO_COUNTRY` for a country without rent.
