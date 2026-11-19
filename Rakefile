# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require "rubocop/rake_task"
require_relative "lib/onlinesim/version"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"]
  t.warning = true
end

RuboCop::RakeTask.new

task default: %i[rubocop test]

# Releases are tagged by hand as X.Y.Z (no `v`), and that tag triggers .github/workflows/release.yml, which runs
# `rake release` (rubygems/release-gem). Bundler's release would create and push a second, `v`-prefixed tag: skip it.
Rake::Task["release:source_control_push"].clear
Rake::Task["release"].clear_comments
Rake::Task["release"].comment = "Build onlinesim-#{OnlineSim::VERSION}.gem and push it to rubygems.org (CI, on an X.Y.Z tag)"
