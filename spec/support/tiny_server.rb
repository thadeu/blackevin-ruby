# frozen_string_literal: true

require "socket"

# One canned HTTP response on a real socket, so the Net::HTTP transport is
# exercised on the wire without any gem: WEBrick left the standard library.
class TinyServer
  attr_reader :port, :received

  def initialize(status: 200, body: "{}", delay: 0)
    @server = TCPServer.new("127.0.0.1", 0)
    @port = @server.addr[1]
    @received = +""

    @thread = Thread.new do
      client = @server.accept
      headers = +""

      headers << client.readline until headers.end_with?("\r\n\r\n")

      length = headers[/content-length: (\d+)/i, 1].to_i
      @received << headers << client.read(length).to_s

      sleep(delay)

      client.write("HTTP/1.1 #{status} X\r\ncontent-type: application/json\r\ncontent-length: #{body.bytesize}\r\nconnection: close\r\n\r\n#{body}")
      client.close
    rescue IOError, SystemCallError
      nil
    end
  end

  def url
    "http://127.0.0.1:#{port}"
  end

  def close
    @server.close
    @thread.join(2)
  end
end
