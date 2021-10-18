# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'onlinesim'

class Tester
  def test
    driver = OnlineSim::Driver.new(:apikey =>  'APIKEY').numbers
    tzid = driver.getwithnumber('vkcom')
    puts tzid['number']
    puts tzid['tzid']
    # countries = driver.countries
    # puts countries
    # puts driver.wait_code(680507)
  end
end

puts Tester.new.test