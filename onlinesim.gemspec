# frozen_string_literal: true

require_relative "lib/onlinesim/version"

Gem::Specification.new do |spec|
  spec.name = "onlinesim"
  spec.version = OnlineSim::VERSION
  spec.authors = ["s00d"]
  spec.email = ["support@onlinesim.ru"]

  spec.summary = "Ruby client for the OnlineSim API: SMS numbers, rent, account and free numbers."
  spec.description = "Zero-dependency Ruby client for the OnlineSim API (Net::HTTP + JSON from the standard library)."
  spec.homepage = "https://github.com/s00d/onlinesim-ruby-api"
  spec.license = "Apache-2.0"
  spec.required_ruby_version = ">= 3.0"

  spec.metadata = {
    # The tag's tree, not the bare repo URL: RubyGems warns when source_code_uri repeats homepage.
    "source_code_uri" => "#{spec.homepage}/tree/#{spec.version}",
    "documentation_uri" => "https://s00d.github.io/onlinesim-ruby-api/",
    "changelog_uri" => "#{spec.homepage}/blob/master/CHANGELOG.md",
    "bug_tracker_uri" => "#{spec.homepage}/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*.rb", "README.md", "CHANGELOG.md", "LICENSE"]
  spec.require_paths = ["lib"]
end
