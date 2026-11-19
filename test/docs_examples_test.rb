# frozen_string_literal: true

require "test_helper"

# Keeps README.md and docs/content/*.md honest: every ```ruby block must compile, every `client.<section>.<method>`
# call must exist, and every signature block (`name(...) # => ...`) must name a method of its page's section.
class DocsExamplesTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SOURCES = ["README.md", *Dir[File.join("docs", "content", "*.md"), base: ROOT].sort].freeze
  SECTIONS = { "numbers.md" => :numbers, "rent.md" => :rent, "user.md" => :user, "free.md" => :free }.freeze

  def blocks
    SOURCES.flat_map do |source|
      File.read(File.join(ROOT, source), encoding: "UTF-8").scan(/```ruby[^\n]*\n(.*?)```/m).map { |(code)| [source, code] }
    end
  end

  def signature?(code)
    code.lines.size == 1 && code.include?("# =>")
  end

  def client
    @client ||= OnlineSim::Client.new(transport: FakeTransport.new([]))
  end

  def test_examples_compile
    assert_operator blocks.size, :>, 40
    blocks.each do |source, code|
      # A signature (`next(tzid) # => true`) compiles as a call on a receiver: bare `next` is the keyword.
      RubyVM::InstructionSequence.compile(signature?(code) ? "self.#{code}" : code)
    rescue SyntaxError => e
      flunk "#{source}: #{e.message}\n#{code}"
    end
  end

  def test_client_calls_exist
    calls = blocks.flat_map { |_, code| code.scan(/\bclient\.(\w+)\.(\w+)/) }.uniq
    assert_operator calls.size, :>, 20
    calls.each do |section, name|
      assert client.public_send(section).respond_to?(name), "client.#{section}.#{name} does not exist"
    end
  end

  def test_signatures_name_real_methods
    blocks.each do |source, code|
      section = SECTIONS[File.basename(source)]
      next unless section && signature?(code)

      name = code[/\A(\w+)/, 1]
      assert client.public_send(section).respond_to?(name), "#{source}: #{section}.#{name} does not exist"
    end
  end

  def test_module_functions_exist
    text = blocks.map(&:last).join
    text.scan(/\bOnlineSim\.(\w+)/).flatten.uniq.each { |name| assert_respond_to OnlineSim, name }
    text.scan(/\bOnlineSim::(\w+)/).flatten.uniq.each { |name| assert OnlineSim.const_defined?(name), name }
  end
end
