# onlinesim

[![Gem Version](https://badge.fury.io/rb/onlinesim.svg)](https://rubygems.org/gems/onlinesim)
[![CI](https://github.com/s00d/onlinesim-ruby-api/actions/workflows/ci.yml/badge.svg)](https://github.com/s00d/onlinesim-ruby-api/actions/workflows/ci.yml)

Ruby client for the [OnlineSim](https://onlinesim.io) API: SMS numbers, rent, account and free numbers.
Zero runtime dependencies (`Net::HTTP` + `JSON` from the standard library), Ruby 3.0+.

```bash
bundle add onlinesim
```

```ruby
require "onlinesim"

client = OnlineSim::Client.new(api_key: ENV["ONLINESIM_KEY"])

b = client.user.balance
puts "available: #{b['balance'] - [b['zbalance'], 0].max} USD"

order = client.numbers.get_with_number("google", 44)
puts "enter #{order['number']} in the app"
puts "code: #{client.numbers.wait_code(order['tzid'])}"
```

## Testing

`OnlineSim::MockOnlineSim` is a built-in offline fake of the API: test your integration without network, key or money.
More in the [testing guide](https://s00d.github.io/onlinesim-ruby-api/testing).

```ruby
require "onlinesim"

mock = OnlineSim::MockOnlineSim.new(balance: 10)
client = mock.client

tzid = client.numbers.get("google", 44)
mock.add_sms_after(tzid, "Your code: 123-456", 2) # arrives on the third poll
raise "wrong code" unless client.numbers.wait_code(tzid, interval: 0) == "123456"
raise "wrong balance" unless mock.balance == 9.8
```

Documentation: **https://s00d.github.io/onlinesim-ruby-api/** · Changes: [CHANGELOG.md](CHANGELOG.md) · License: Apache-2.0
