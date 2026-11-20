---
title: Testing
description: Test your integration offline with MockOnlineSim — no network, key or money.
navigation:
  order: 6
---

`OnlineSim::MockOnlineSim` is an in-process fake of the OnlineSim API that ships with the gem. It is a transport that answers like the real backend — same shapes, same error codes, HTTP 456 for a wrong key — and keeps a balance, operations and rents. Your code talks to a normal `OnlineSim::Client`, so nothing in it changes for tests. It is deterministic: no randomness, no clock, numbers and ids come from a counter.

## Setup

```ruby
require "onlinesim" # MockOnlineSim is autoloaded on first use; `require "onlinesim/mock"` works too

mock = OnlineSim::MockOnlineSim.new(balance: 10)
client = mock.client # an OnlineSim::Client wired to the mock
```

```ruby
OnlineSim::MockOnlineSim.new(api_key: "mock-key", balance: 100, prices: nil, rent_tariffs: nil, guard_interval: 0)
```

| Option | Default | Description |
|---|---|---|
| `api_key` | `"mock-key"` | Key the mock accepts. `mock.client` uses it; `mock.client(api_key: "x")` tests a wrong key. |
| `balance` | `100` | Starting balance, USD. |
| `prices` | `{ 7 => { "vkcom" => 0.5, "telegram" => 1.2, "google" => 0.3 }, 44 => { "google" => 0.2, "vkcom" => 0.36 } }` | Number prices, country code → service slug → USD; replaces the defaults. Also feeds `numbers.tariffs`. |
| `rent_tariffs` | `{ 7 => { days: { 1 => 1.0, 3 => 2.5, 7 => 5.0 }, extend: 1 } }` | Rent prices; `extend: 0` makes rents of that country non-extendable. |
| `guard_interval` | `0` | `> 0`: an operation without SMS, or an unconfirmed rent without any SMS, cannot be closed (`NO_COMPLETE_TZID`). |

`mock.client(**options)` takes the usual [client options](/#client-options) except `transport:`. To build the client yourself, pass `mock.transport` (the mock itself) as `transport:`; any `base_url` works:

```ruby
mock = OnlineSim::MockOnlineSim.new
client = OnlineSim::Client.new(api_key: "mock-key", transport: mock.transport)
```

## A full example

Order a number, let an SMS arrive while `wait_code` polls, check the code and the money. `add_sms_after` delivers the SMS after a number of polls instead of after some time, so `wait_code` runs with `interval: 0` and the test takes milliseconds.

```ruby
require "minitest/autorun"
require "onlinesim"

class ReceiveCodeTest < Minitest::Test
  def test_receives_the_code
    mock = OnlineSim::MockOnlineSim.new(balance: 10)
    client = mock.client

    order = client.numbers.get_with_number("google", 44)
    assert_equal "+44900000001", order["number"]

    mock.add_sms_after(order["tzid"], "Your Google code: 123-456", 2) # the third poll sees it
    code = client.numbers.wait_code(order["tzid"], interval: 0)

    assert_equal "123456", code
    assert_equal "TZ_OVER_OK", mock.operations.first.status # wait_code closed it
    assert_in_delta 9.8, mock.balance # the price is spent once an SMS arrived
  end
end
```

The `msg` of an operation is the code by default: the first run of 4–8 digits, with spaces and dashes between digits removed (`123-456` → `123456`); a text without such a run comes back whole. `message_to_code: false` (or `full_message: true` in `wait_code`) gives the full text.

## Errors

`fail_next(code)` makes the next request answer `{"response": code}` — the client turns it into `ApiError` (or `NoNumberError`) exactly as for the real server. Pass `endpoint:` to fail only that endpoint. `fail_next_transport` makes the next request fail with a non-JSON HTTP 502 (`TransportError`).

```ruby
def test_handles_a_missing_number_and_a_network_hiccup
  mock = OnlineSim::MockOnlineSim.new
  client = mock.client

  mock.fail_next("NO_NUMBER", endpoint: "getNum.php")
  assert_raises(OnlineSim::NoNumberError) { client.numbers.get("google") }

  mock.fail_next_transport(status: 503)
  assert_raises(OnlineSim::TransportError) { client.user.balance }

  assert_in_delta 100, client.user.balance["balance"] # one-shot
end
```

The state itself produces the real error codes too: `WARNING_LOW_BALANCE` when the balance is short, `NO_NUMBER` when `reject` matches the next number, `UNDEFINED_COUNTRY` / `ERROR_NO_SERVICE` for unknown prices, `ERROR_WRONG_TZID` for an unknown or closed operation (`next` too; `ERROR_NO_TZID` for tzid `0`), `UNDEFINED_COUNTRY` / `UNDEFINED_DAYS` for an unknown rent country or period, `TRY_AGAIN_LATER` for every refused `rent.extend`, `ERROR_NO_OPERATIONS` for an unknown rent in `rent.close`, `ERROR_WRONG_KEY` for a wrong key (HTTP 456) or no key (HTTP 200).

## Inspecting requests

`mock.requests` lists every request received as `{ method:, path:, query:, body: }`: `path` relative to `/api/`, `query` with String keys and values, `body` the parsed JSON of a POST (`nil` for GET).

```ruby
def test_sends_reject_as_a_comma_list
  mock = OnlineSim::MockOnlineSim.new
  mock.client.numbers.get("google", 44, reject: %w[4470 4471])

  assert_equal [{ method: "GET", path: "getNum.php",
                  query: { "service" => "google", "country" => "44", "reject" => "4470,4471", "lang" => "en" },
                  body: nil }], mock.requests
end
```

## Control API

| Member | Description |
|---|---|
| `client(**options)` | A normal `OnlineSim::Client` wired to the mock. |
| `transport` | The mock itself (it implements `call(method, url, headers, body, timeout)`). |
| `add_sms(tzid, text, service: nil)` | An SMS arrives now at a number operation or a rent (detected by `tzid`). Raises `ArgumentError` for an unknown or closed one. |
| `add_sms_after(tzid, text, polls, service: nil)` | The SMS arrives after `polls` state requests for `tzid` (`numbers.state`/`state_one`, `rent.state`/`state_one`). |
| `fail_next(code, endpoint: nil)` | The next request (to `endpoint` only, e.g. `"getNum.php"`) answers `{"response": code}`. |
| `fail_next_transport(status: 502, endpoint: nil)` | The next request fails with a non-JSON body and HTTP `status`. |
| `set_balance(usd)` / `balance` | Set / read the total balance, USD (it includes the part frozen by open operations and unconfirmed rents, as `user.balance` reports it). |
| `operations` / `rents` | Copies of the current number operations / open rents (`Struct`s: `tzid`, `status`, `messages`, …), for assertions. |
| `requests` | Log of the requests received (a copy). |
| `reset` | Back to the constructor's state. |

## What the mock does

- **Numbers**: `get` freezes the price; `close` after an SMS spends it, `close` without one refunds it; `ban` after an SMS answers `"0"`, like the server. Numbers are `+<country>9000000NN`, ids count from 1. `next` switches to the following SMS. The operation's `time` stays at 1200 s — there is no clock.
- **Rent**: `get` reserves the price (`status` `0`, `checked` `false`) and keeps the `extension` flag; the first SMS that is not `notify` confirms the rent (`status` `1`) and charges it — `add_sms(tzid, text, service: "notify")` adds a notice with `code` `0` that confirms nothing. `extend` works on a confirmed rent and charges at once. `close` releases the reservation of an unconfirmed rent and gives no refund for a confirmed one. `sum` is a number in `get`/`extend` and a decimal string on the wire of `state`, like the server. SMS appear in `messages`, newest first.
- **User**: `balance` (frozen part included), a fixed profile, `set_webhook_url` accepts any `scheme://…` URL (`VALIDATION_ERROR` otherwise), `webhook_logs` lists the deliveries the mock *recorded* when an SMS arrived while a webhook URL was set — it makes no HTTP call; their `params` follow the real payload (`code` `""` without a code, rent `number` in digits without `+`, rent `time_left` in minutes). `payment_history` has no orders.
- **Free**: `free.list` returns two fixed countries (44 first) with one number and a few SMS each.
- Not imitated: anything that needs real time — the 5 s lock after `setOperationOk` (`INTERVAL_CONCURRENT_REQUESTS_ERROR`), the 10 s lock of `rent.extend`, the 120 s before an unconfirmed rent may be closed and its 20-minute wait for the first SMS. `guard_interval > 0` stands in for "too early to close".
