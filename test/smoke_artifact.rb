# frozen_string_literal: true

# Smoke test of the PUBLISHED artifact: `gem build --strict` (warnings fail), check the .gem holds only lib/ +
# README/LICENSE/CHANGELOG, install it with `--install-dir` into an empty temp dir and run the README "Testing"
# example (offline, against MockOnlineSim) with GEM_HOME/GEM_PATH pointing there, outside Bundler.
#
#   ruby test/smoke_artifact.rb

require "English"
require "rbconfig"
require "tmpdir"

ROOT = File.expand_path("..", __dir__)
# The `gem` of the Ruby running this script (CI runs it on the floor and the latest Ruby).
GEM = File.join(RbConfig::CONFIG["bindir"], "gem")

def run!(env, *cmd, chdir:)
  output = IO.popen(env, cmd, chdir: chdir, err: %i[child out], &:read)
  raise "#{cmd.join(" ")} failed (#{$CHILD_STATUS}):\n#{output}" unless $CHILD_STATUS.success?

  output
end

# A clean environment for the installed gem: no Bundler, no load path from this checkout.
def isolated(gem_dir)
  keys = ENV.keys.grep(/\A(BUNDLE_|BUNDLER_|RUBYOPT\z|RUBYLIB\z|GEM_)/)
  keys.to_h { |k| [k, nil] }.merge("GEM_HOME" => gem_dir, "GEM_PATH" => gem_dir)
end

Dir.mktmpdir("onlinesim-smoke-") do |dir|
  tmp = File.realpath(dir) # macOS: /var is a symlink to /private/var
  gem_file = File.join(tmp, "onlinesim.gem")
  puts run!(isolated(Gem.dir), GEM, "build", "--strict", "onlinesim.gemspec", "--output", gem_file, chdir: ROOT)

  files = run!({}, GEM, "spec", gem_file, "files", chdir: tmp).lines.grep(/\A- /).map { |l| l[2..].strip }.sort
  stray = files.grep_v(%r{\A(lib/.+\.rb|README\.md|LICENSE|CHANGELOG\.md)\z})
  raise "unexpected files in the gem: #{stray}" unless stray.empty?

  %w[lib/onlinesim.rb lib/onlinesim/mock.rb README.md LICENSE CHANGELOG.md].each do |f|
    raise "the gem lacks #{f}" unless files.include?(f)
  end
  puts "built #{File.basename(gem_file)}: #{files.size} files"

  gems = File.join(tmp, "gems")
  env = isolated(gems)
  run!(env, GEM, "install", "--local", "--no-document", "--install-dir", gems, gem_file, chdir: tmp)

  app = File.join(tmp, "app")
  Dir.mkdir(app)
  where = run!(env, RbConfig.ruby, "-e", 'require "onlinesim"; print Gem.loaded_specs.fetch("onlinesim").full_gem_path',
               chdir: app)
  raise "onlinesim loaded from #{where}, not from #{gems}" unless where.start_with?(gems)

  readme = File.read(File.join(where, "README.md"), encoding: "UTF-8")
  example = readme[/^## Testing\n.*?```ruby\n(.*?)```/m, 1] or raise 'README.md has no "## Testing" section with a ruby example'
  File.write(File.join(app, "readme_testing.rb"), example)
  run!(env, RbConfig.ruby, "readme_testing.rb", chdir: app)
  puts "README \"Testing\" example: ok (ruby #{RUBY_VERSION}, gem from #{where})"
end
