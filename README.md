# Onlinesim Ruby API


Wrapper for automatic reception of SMS-messages by onlinesim.ru

[![Gem Version](https://badge.fury.io/rb/ribose.svg)](https://badge.fury.io/rb/ribose)


### Installation
You can install or upgrade package with:
```bash
$ gem install onlinesim
```
### Example
```ruby
require 'onlinesim'

module MyModule
  class Tester
    def test
      driver = OnlineSim::Driver.new(:apikey =>  'TOKEN').numbers
      tzid = driver.get('vkcom')
      puts driver.stateone(tzid)['number']
      puts driver.wait_code(tzid)
    end
  end
end

puts MyModule::Tester.new.test
```

## Documentation

All documentation is in the wiki of this project - **[Documentation](https://github.com/s00d/onlinesim-python-api/wiki)**

## Bugs

If you have any problems, please create Issues here 
https://github.com/s00d/onlinesim-python-api/issues
