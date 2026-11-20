# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.1] - 2026-11-20

Aligned with the regenerated backend API spec.

### Fixed

- `user.payment_history` no longer drops `paylist` when the server sends it as a JSON array (ids 0, 1, 2…); it is returned as sent.
- `numbers.wait_code` retries `ApiError` `TRY_AGAIN_LATER` (HTTP 429 rate limit), `ERROR_UNDEFINED` and `INTERVAL_CONCURRENT_REQUESTS_ERROR` until its timeout instead of raising at once.
- Error messages: `"0"` (ban not applied, the operation already has an SMS), `ACCOUNT_CLEANED`, `USER_NOT_ACTIVATED`, `ERROR_UNDEFINED`, `FORWARD_NOT_SUPPORTED` added; `ERROR_NO_KEY`, `NO_NUMBER_FOR_FORWARD`, `ACCOUNT_IDENTIFICATION_REQUIRED`, `API_DISABLED` (no longer sent) removed; `ERROR_WRONG_KEY` reads "Wrong or missing API key". `NoNumberError` is raised for `NO_NUMBER` only.
- `MockOnlineSim` follows the backend: `setOperationRevise` answers `{"tzid":"N","response":"1"}` and `ERROR_WRONG_TZID` / `ERROR_NO_TZID`; `setOperationOk` tzid `0` → `ERROR_NO_TZID`; a missing key is HTTP 200 `ERROR_WRONG_KEY` (456 only for a wrong key, also on public endpoints); `getNum` with `number` adds `title`, `response_text`, `guard_interval_remaining_seconds`. Rent: `getRentNum` reserves the price (`status` 0) and the first non-`notify` SMS confirms and charges it (a `notify` SMS has the integer `code` `0`), unknown country → `UNDEFINED_COUNTRY`, `sum` a number in getRentNum/extendRentState and a string in getRentState, `guard_interval_remaining_seconds` with `number`; `extendRentState` refusals are all `TRY_AGAIN_LATER`; `closeRentNum` unknown tzid → `ERROR_NO_OPERATIONS`, releases the reservation of an unconfirmed rent. Webhook-log params: `code` `""` without a code, rent `number` in full digits, rent `time_left` in minutes, `time_start` per type. `profile.php` accepts any `scheme://…` URL. `getPaymentHistory` adds `forms`/`buttons`; `getFreeList` clamps `count` to 10..500, sends ISO-8601 `created_at` and `ignore`/`content`.
- Docs: rent reservation and `sum`, available = balance − max(zbalance, 0), `ban` answer `"0"`, webhook `number`/`time_left`/`time_start`, the `wait_code` retry policy, rent message `code` `0`, nullable profile/payment/free fields, the mock's behaviour.

## [2.1.0] - 2026-11-19

### Added

- `OnlineSim::MockOnlineSim`: a built-in, in-process fake of the OnlineSim API for testing integrations offline — no network, key, money or clock. `mock.client` returns a normal `OnlineSim::Client` wired to it (`mock.transport` is the mock itself, a transport with `call(method, url, headers, body, timeout)`). It answers every endpoint the SDK calls like the real backend (HTTP 456 for a wrong key, string/int `response`, decimal-string money, `[]` for empty maps) and keeps balance, operations and rents. Test helpers: `add_sms`, `add_sms_after` (lets `wait_code` run with `interval: 0`), `fail_next`, `fail_next_transport`, `set_balance`, `balance`, `operations`, `rents`, `requests`, `reset`. Autoloaded by `require "onlinesim"` (nothing is loaded until first use); `require "onlinesim/mock"` works too. See the [testing guide](https://s00d.github.io/onlinesim-ruby-api/testing).
- Packaging checks in CI: `gem build --strict` (warnings fail the build) and a smoke test that builds the gem, installs it with `--install-dir` into an empty directory and runs the README "Testing" example on Ruby 3.0 and the latest Ruby.
- `.github/workflows/release.yml`: a version tag runs CI, checks the tag against `OnlineSim::VERSION`, publishes to RubyGems with trusted publishing (OIDC, no API key) and creates the GitHub release from this file.

### Changed

- Gemspec `source_code_uri` points to the release tag's tree, so it no longer repeats `homepage` (RubyGems warned about the duplicate).

## [2.0.0] - 2026-11-19

A rewrite. The public API changed; see the [docs](https://s00d.github.io/onlinesim-ruby-api/).

### Removed

- Runtime dependencies `faraday`, `oj`, `thor`; the `onlinesim` CLI (`cli.rb`).
- The global `Faraday::Connection` monkeypatch that disabled TLS verification for every Faraday client in the process, and `Faraday.ignore_env_proxy`.
- The proxy API (`driver.proxy`) and the forward API (`driver.forward`, `getForward`).
- `numbers.service` (getService), `numbers.servicenumber` (getServiceNumber), `forward.repeat` (getNumRepeat): no backend route.
- `free.countries`, `free.numbers`, `free.messages`: the backend returns empty data for them; use `free.list`.
- `OnlineSim::Driver`, `Onlinesim::VERSION` (now `OnlineSim::VERSION`), `ServerError`, `BaseError`.
- `tester.rb`, `.travis.yml`, `bin/`, the committed `Gemfile.lock` and the `bundler ~> 2.2.27` dev pin.

### Changed

- One client: `OnlineSim::Client.new(api_key:, base_url:, lang:, dev_id:, timeout:, transport:)`; sections are readers (`client.numbers`, `client.rent`, `client.user`, `client.free`).
- The API key is sent as `Authorization: Bearer <key>`, never in the query string.
- Errors: `OnlineSim::Error` → `ApiError` (`code`, `message`), `NoNumberError` (subclass of `ApiError`), `TransportError` (`status`, `body`), `TimeoutError`.
- Method names are snake_case: `get_with_number`, `state_one`, `tariffs_one`, `payment_history`, `wait_code`.
- `numbers.get(service, country = 7, reject: [...])`; `state(message_to_code:, order_by:, msg_list:)` / `state_one(tzid, ...)` take booleans; `order_by` is lowercase.
- `numbers.wait_code(tzid, interval: 5, timeout: 600, keep_open: false, full_message: false, since: nil)`, seconds, injectable `sleep:` / `now:`.
- `rent.get(country = 7, days = 1, extension: true)`: `extension` defaults to `true` (the server default; `false` makes the rent non-extendable for good).
- Results keep the server's string keys; money parsed to `Float`: `user.balance["balance"]`, rent `sum`.
- Ruby >= 3.0; gemspec license matches LICENSE (Apache-2.0); `Gemfile.lock` is not committed (library).

### Fixed

- TLS certificates are verified (v1 disabled verification globally); the environment proxy is honoured.
- The host was hardcoded; `base_url` is configurable. No more double slashes (`/api//rent/...`).
- `dev_id` was always sent (empty); now only when set. Booleans are sent as `1`/`0`; unset parameters are omitted.
- `reject: {}` default and the stray `&&` in its encoding; `reject` is now a comma list.
- Error mapping was dead code (the check was a method defined inside the request but never called), so error codes came back as data. They now raise `ApiError`; an HTTP 456 wrong-key answer is an `ApiError`, non-JSON answers raise `TransportError`.
- `wait_code` closed the operation on the first poll, before any SMS (`nil != ""`), and gave up after 10 polls; it now returns only a real code, then closes.
- `rent.extend` sent no `days`; it now takes `days` (default 1).
- `state` sent `orderby=ASC`; the server accepts only lowercase. `state` returns `[]` instead of raising when there are no operations.
- Empty maps sent by PHP as `[]` (rent `extend`, `paylist`, free `numbers`, country `services`) are returned as `{}`.
- Rent requests always send `pagination=0`, so `messages` is a flat list.

### Added

- `user.set_webhook_url(url)`, `user.clear_webhook_url`, `user.webhook_logs(page)`, `user.payment_history(page)`.
- `free.list(country:, number:, page:, count:)`.
- `OnlineSim.parse_webhook(payload)` for inbound `receiving_sms` / `rent_sms` webhooks.
- Injectable transport (`OnlineSim::NetHttpTransport` by default) and per-request `timeout`.
- Offline test suite (minitest, fake transport), opt-in integration test, RuboCop, CI on Ruby 3.0 and latest.
- Documentation site (Nuxt Content).

## [1.0.6] - 2019-08-12
### Changed
- fix proxy

## [1.0.5] - 2019-08-11
### Changed
- remove proxy

## [1.0.4] - 2019-08-10
### Changed
- change homepage

## [1.0.0] - 2019-08-10
### Added
- Project
