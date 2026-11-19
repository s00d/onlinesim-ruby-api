# frozen_string_literal: true

require "test_helper"
require "socket"

# The stdlib transport against a one-shot HTTP server on 127.0.0.1 (no external host, no sleeps).
class NetHttpTransportTest < Minitest::Test
  def serve(status, body)
    server = TCPServer.new("127.0.0.1", 0)
    seen = Queue.new
    thread = Thread.new do
      socket = server.accept
      head = +""
      head << socket.gets until head.end_with?("\r\n\r\n")
      length = head[/^content-length:\s*(\d+)/i, 1].to_i
      seen << [head, socket.read(length)]
      socket.write("HTTP/1.1 #{status} X\r\nContent-Type: application/json\r\nContent-Length: #{body.bytesize}\r\n" \
                   "Connection: close\r\n\r\n#{body}")
      socket.close
    end
    yield "http://127.0.0.1:#{server.addr[1]}/api/", seen
  ensure
    thread&.join
    server&.close
  end

  def test_get_round_trip_through_the_client
    serve(200, '{"response":"1","price":0.5,"text":"привет"}') do |base, seen|
      client = OnlineSim::Client.new(api_key: "k", base_url: base)
      assert_in_delta 0.5, client.numbers.price("vkcom", 44)
      head, = seen.pop
      assert_match %r{\AGET /api/getPrice\.php\?service=vkcom&country=44&lang=en HTTP/1\.1}, head
      assert_match(/^authorization: Bearer k\r$/i, head)
    end
  end

  def test_post_sends_the_json_body
    serve(200, '{"response":"1"}') do |base, seen|
      assert OnlineSim::Client.new(api_key: "k", base_url: base).user.set_webhook_url("https://example.com/h")
      head, body = seen.pop
      assert_match %r{\APOST /api/profile\.php\?lang=en HTTP/1\.1}, head
      assert_equal({ "profile" => { "webhook_url" => "https://example.com/h" } }, JSON.parse(body))
    end
  end

  def test_returns_status_and_utf8_body
    serve(456, '{"response":"ERROR_WRONG_KEY"}') do |base, _seen|
      status, body = OnlineSim::NetHttpTransport.new.call("GET", "#{base}x", {}, nil, 5)
      assert_equal 456, status
      assert_equal Encoding::UTF_8, body.encoding
    end
  end
end
