# Free numbers

> Public numbers and their SMS — client.free. No API key needed.

## list

Countries, the numbers of the selected country and the SMS of the selected number, in one call.

```ruby
list(country: nil, number: nil, page: nil, count: nil) # => Hash
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
        country:
      </code>
    </td>
    
    <td>
      <code>
        Integer
      </code>
    </td>
    
    <td>
      <code>
        44
      </code>
      
       (server)
    </td>
    
    <td>
      Country code; an unknown one falls back to the first available.
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        number:
      </code>
    </td>
    
    <td>
      <code>
        String
      </code>
    </td>
    
    <td>
      first number
    </td>
    
    <td>
      Number <strong>
        without
      </strong>
      
       the country code, as the keys of <code>
        "numbers"
      </code>
      
      .
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        page:
      </code>
    </td>
    
    <td>
      <code>
        Integer
      </code>
    </td>
    
    <td>
      <code>
        1
      </code>
    </td>
    
    <td>
      Page of <code>
        "messages"
      </code>
      
      .
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        count:
      </code>
    </td>
    
    <td>
      <code>
        Integer
      </code>
    </td>
    
    <td>
      server default
    </td>
    
    <td>
      SMS per page, 10–500.
    </td>
  </tr>
</tbody>
</table>

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
