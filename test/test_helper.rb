# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "onlinesim"
require "minitest/autorun"
require "json"
require "uri"

# Fake transport: answers canned replies in order and records every call.
# A reply is a Hash (`json:` value or `raw:` body, optional `status:`) or an Exception to raise.
class FakeTransport
  Call = Struct.new(:http_method, :url, :headers, :body, :timeout, keyword_init: true) do
    def uri = URI(url)
    def path = uri.path

    # Query as a Hash, without the `lang` every request carries.
    def query
      URI.decode_www_form(uri.query.to_s).to_h.except("lang")
    end

    def json_body = body && JSON.parse(body)
  end

  attr_reader :calls

  def initialize(replies)
    @replies = replies.dup
    @calls = []
  end

  def call(method, url, headers, body, timeout)
    @calls << Call.new(http_method: method, url: url, headers: headers.dup, body: body, timeout: timeout)
    reply = @replies.shift or raise "unexpected request #{url}"
    raise reply if reply.is_a?(Exception)

    [reply.fetch(:status, 200), reply.fetch(:raw) { JSON.generate(reply[:json]) }]
  end

  # The only call made; fails when there were more or none.
  def last
    raise "expected 1 request, got #{@calls.size}" unless @calls.size == 1

    @calls.first
  end
end

module ClientHelpers
  def fake_client(replies, **options)
    transport = FakeTransport.new(replies)
    client = OnlineSim::Client.new(api_key: "test-key", base_url: "https://api.test/api/", transport: transport, **options)
    [client, transport]
  end

  def fixture(name)
    JSON.parse(File.read(File.join(__dir__, "fixtures", "#{name}.json"), encoding: "UTF-8"))
  end
end
