---
title: Changelog
description: Release notes of the onlinesim Ruby gem.
navigation:
  order: 7
---

The full history is in [CHANGELOG.md](https://github.com/s00d/onlinesim-ruby-api/blob/master/CHANGELOG.md).

## 2.1.1

- `wait_code` retries `TRY_AGAIN_LATER` (rate limit), `ERROR_UNDEFINED` and `INTERVAL_CONCURRENT_REQUESTS_ERROR`.
- `payment_history["paylist"]` is kept when it arrives as a list; error messages follow the current API.
- `MockOnlineSim` follows the backend more closely: rent reservation and confirmation, `setOperationRevise` and `closeRentNum` answers, missing vs wrong key — see [Testing](/testing).

## 2.1.0

- New: `OnlineSim::MockOnlineSim`, an offline fake of the API for your tests — see [Testing](/testing).

## 2.0.0

A rewrite with a new API; v1 code does not run unchanged.

- One client, `OnlineSim::Client.new(api_key:)`, with the sections as readers: `client.numbers`, `client.rent`, `client.user`, `client.free`.
- Zero runtime dependencies (`Net::HTTP` + `JSON`), Ruby 3.0+. TLS is verified (v1 disabled verification globally).
- The key is sent as a Bearer header, never in the URL.
- Typed errors: `ApiError`, `NoNumberError`, `TransportError`, `TimeoutError`.
- `numbers.wait_code` waits for a real SMS: interval and timeout in seconds, `keep_open:`, `since:`, retries network errors.
- `rent.get` creates extendable rents by default (`extension: true`); `rent.extend` takes `days`.
- New: `user.set_webhook_url` / `clear_webhook_url` / `webhook_logs`, `OnlineSim.parse_webhook`.
- Removed: the proxy API, the forward API, the `onlinesim` CLI, `numbers.service` / `service_number`, `rent.port_reload`, `free.countries` / `numbers` / `messages` (use `free.list`).
