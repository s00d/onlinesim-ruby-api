# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'onlinesim'

class Tester
  def test
    driver = OnlineSim::Driver.new(:apikey =>  '').free
    # tzid = driver.get('odklru')
    # puts tzid
    countries = driver.countries
    puts countries
    # puts driver.wait_code(680507)
  end
end

puts Tester.new.test