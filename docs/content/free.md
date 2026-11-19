---
title: Free numbers
description: Public numbers and their SMS — client.free. No API key needed.
navigation:
  order: 4
---

## list

Countries, the numbers of the selected country and the SMS of the selected number, in one call.

```ruby
list(country: nil, number: nil, page: nil, count: nil) # => Hash
```

| Option | Type | Default | Description |
|---|---|---|---|
| `country:` | `Integer` | `44` (server) | Country code; an unknown one falls back to the first available. |
| `number:` | `String` | first number | Number **without** the country code, as the keys of `"numbers"`. |
| `page:` | `Integer` | `1` | Page of `"messages"`. |
| `count:` | `Integer` | server default | SMS per page, 10–500. |

Result:

- `"countries"`: `[{"country", "country_text", "country_original"}]`
- `"numbers"`: `{short_number => {"country", "country_original", "full_number", "data_humans", "is_archive"}}`
- `"messages"`: a paginator of `{"id", "text", "in_number", "my_number", "code", "created_at", "data_humans"}` plus `"number"` and `"country"`; `code` is `-` when no code was found

```ruby
numbers = client.free.list(country: 44)["numbers"]
short = numbers.keys.first
if short
  messages = client.free.list(country: 44, number: short, count: 20)["messages"]
  messages["data"].each { |sms| puts sms.values_at("in_number", "code", "text").join(" ") }
end
```
