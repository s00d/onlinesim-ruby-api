# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "onlinesim/version"

Gem::Specification.new do |spec|
  spec.name          = 'onlinesim'
  spec.version       = Onlinesim::VERSION
  spec.authors       = ['s00d']
  spec.email         = ['support@onlinesim.ru']

  spec.summary       = 'onlinesim.ru Ruby API wrapper'
  spec.homepage      = 'https://github.com/s00d/onlinesim-ruby-api'
  spec.license       = 'MIT'

  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.require_paths = ["lib"]

  spec.add_dependency 'faraday', '~> 1.0'
  spec.add_dependency 'oj',    '~> 3.10'
  spec.add_dependency 'thor'
  spec.add_development_dependency "bundler", "~> 2.1.4"
end