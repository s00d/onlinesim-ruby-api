# Numbers

> Order a number, read its SMS, close it — client.numbers.

An operation (`tzid`) is one ordered number. Order it with `get`/`get_with_number`, read the SMS with `state_one` or `wait_code`, finish it with `close` (or `ban`). Countries are phone codes (`7`, `44`, …), services are slugs (`google`, `vkcom`, …) as returned by `tariffs`.

## price

Price of one number, USD; `nil` when the country has no price for the service.

```ruby
price(service, country = 7) # => Float or nil
```

<table>
<thead>
  <tr>
    <th>
      Param
    </th>
    
    <th>
      Type
    </th>
    
    <th>
      Default
    </th>
    
    <th>
      Description
    </th>
  </tr>
</thead>

<tbody>
  <tr>
    <td>
      <code>
        service
      </code>
    </td>
    
    <td>
      <code>
        String
      </code>
    </td>
    
    <td>
      —
    </td>
    
    <td>
      Service slug.
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        country
      </code>
    </td>
    
    <td>
      <code>
        Integer
      </code>
    </td>
    
    <td>
      <code>
        7
      </code>
    </td>
    
    <td>
      Country code.
    </td>
  </tr>
</tbody>
</table>

```ruby
usd = client.numbers.price("google", 44)
```

Errors: `ApiError` `ERROR_NO_SERVICE`, `UNDEFINED_COUNTRY`.

## get

Order a number; returns the operation id. Freezes the price on the balance.

```ruby
get(service, country = 7, reject: nil) # => Integer (tzid)
```

<table>
<thead>
  <tr>
    <th>
      Param
    </th>
    
    <th>
      Type
    </th>
    
    <th>
      Default
    </th>
    
    <th>
      Description
    </th>
  </tr>
</thead>

<tbody>
  <tr>
    <td>
      <code>
        service
      </code>
    </td>
    
    <td>
      <code>
        String
      </code>
    </td>
    
    <td>
      —
    </td>
    
    <td>
      Service slug.
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        country
      </code>
    </td>
    
    <td>
      <code>
        Integer
      </code>
    </td>
    
    <td>
      <code>
        7
      </code>
    </td>
    
    <td>
      Country code.
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        reject:
      </code>
    </td>
    
    <td>
      <code>
        Array
      </code>
    </td>
    
    <td>
      profile list
    </td>
    
    <td>
      Number prefixes to skip, e.g. <code>
        ["4470"]
      </code>
      
      .
    </td>
  </tr>
</tbody>
</table>

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

<table>
<thead>
  <tr>
    <th>
      Option
    </th>
    
    <th>
      Type
    </th>
    
    <th>
      Default
    </th>
    
    <th>
      Description
    </th>
  </tr>
</thead>

<tbody>
  <tr>
    <td>
      <code>
        message_to_code:
      </code>
    </td>
    
    <td>
      <code>
        Boolean
      </code>
    </td>
    
    <td>
      <code>
        true
      </code>
    </td>
    
    <td>
      <code>
        msg
      </code>
      
       is the code only; <code>
        false
      </code>
      
       — the full SMS text.
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        order_by:
      </code>
    </td>
    
    <td>
      <code>
        "asc"
      </code>
      
      , <code>
        "desc"
      </code>
    </td>
    
    <td>
      <code>
        "asc"
      </code>
    </td>
    
    <td>
      Order of operations.
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        msg_list:
      </code>
    </td>
    
    <td>
      <code>
        Boolean
      </code>
    </td>
    
    <td>
      <code>
        false
      </code>
    </td>
    
    <td>
      <code>
        msg
      </code>
      
       is a list of all SMS (<code>
        [{"service", "msg"}]
      </code>
      
      ).
    </td>
  </tr>
</tbody>
</table>

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

<table>
<thead>
  <tr>
    <th>
      Option
    </th>
    
    <th>
      Type
    </th>
    
    <th>
      Default
    </th>
    
    <th>
      Description
    </th>
  </tr>
</thead>

<tbody>
  <tr>
    <td>
      <code>
        interval:
      </code>
    </td>
    
    <td>
      <code>
        Numeric
      </code>
    </td>
    
    <td>
      <code>
        5
      </code>
    </td>
    
    <td>
      Poll interval, seconds.
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        timeout:
      </code>
    </td>
    
    <td>
      <code>
        Numeric
      </code>
    </td>
    
    <td>
      <code>
        600
      </code>
    </td>
    
    <td>
      Give up after, seconds.
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        keep_open:
      </code>
    </td>
    
    <td>
      <code>
        Boolean
      </code>
    </td>
    
    <td>
      <code>
        false
      </code>
    </td>
    
    <td>
      Call <code>
        next(tzid)
      </code>
      
       instead of <code>
        close(tzid)
      </code>
      
      , to wait for another SMS.
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        full_message:
      </code>
    </td>
    
    <td>
      <code>
        Boolean
      </code>
    </td>
    
    <td>
      <code>
        false
      </code>
    </td>
    
    <td>
      Return the full SMS text instead of the code.
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        since:
      </code>
    </td>
    
    <td>
      <code>
        String
      </code>
      
      , <code>
        nil
      </code>
    </td>
    
    <td>
      <code>
        nil
      </code>
    </td>
    
    <td>
      Ignore this value (the previous code).
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        sleep:
      </code>
      
      , <code>
        now:
      </code>
    </td>
    
    <td>
      callables
    </td>
    
    <td>
      <code>
        Kernel#sleep
      </code>
      
      , monotonic clock
    </td>
    
    <td>
      Injectable for tests (seconds).
    </td>
  </tr>
</tbody>
</table>

Transient errors are retried until the timeout: `TransportError`, and `ApiError` `TRY_AGAIN_LATER` (the HTTP 429 rate limit), `ERROR_UNDEFINED` and `INTERVAL_CONCURRENT_REQUESTS_ERROR`. Any other `ApiError` is raised at once. Also available as `OnlineSim.wait_code(numbers, tzid, **options)`.

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

Errors: `ApiError` `ERROR_WRONG_TZID` (not an operation of your account), `ERROR_NO_TZID`.

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

Errors: as `close`; `ApiError` with code `"0"` when the operation already has an SMS — nothing is changed then.

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
