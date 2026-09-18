# frozen_string_literal: true

require "net/http"
require "openssl"
require "uri"

module Blackevin
  # One HTTP exchange, as the transport sees it.
  Request = Struct.new(:method, :url, :headers, :body, keyword_init: true)
  Response = Struct.new(:status, :body, keyword_init: true)

  # The default transport: Net::HTTP from the standard library, and nothing else.
  #
  # Anything responding to +call(request)+ and returning a {Response} can stand
  # in for it, which is how the specs observe a request without sending one and
  # how an application can route through its own HTTP stack.
  class Transport
    NETWORK_ERRORS = [
      SocketError,
      SystemCallError,
      IOError,
      Timeout::Error,
      OpenSSL::SSL::SSLError,
      Net::HTTPBadResponse,
      Net::ProtocolError
    ].freeze

    VERBS = {
      "GET" => Net::HTTP::Get,
      "POST" => Net::HTTP::Post,
      "PUT" => Net::HTTP::Put,
      "PATCH" => Net::HTTP::Patch,
      "DELETE" => Net::HTTP::Delete
    }.freeze

    # @param open_timeout [Numeric] seconds to wait for the connection
    # @param read_timeout [Numeric] seconds to wait for each read
    def initialize(open_timeout: 5, read_timeout: 10)
      @open_timeout = open_timeout
      @read_timeout = read_timeout
    end

    # @param request [Blackevin::Request]
    # @return [Blackevin::Response]
    # @raise [Blackevin::ConnectionError] when no response arrived
    def call(request)
      uri = URI.parse(request.url)
      http_request = build(request, uri)

      response = connection(uri).start { |http| http.request(http_request) }

      Response.new(status: response.code.to_i, body: response.body)
    rescue *NETWORK_ERRORS => e
      raise ConnectionError, "could not reach #{uri&.host || request.url}: #{e.class}: #{e.message}"
    end

    private

    def build(request, uri)
      http_request = VERBS.fetch(request.method).new(uri.request_uri)

      request.headers.each { |name, value| http_request[name] = value }
      http_request.body = request.body if request.body

      http_request
    end

    def connection(uri)
      http = Net::HTTP.new(uri.host, uri.port)

      http.use_ssl = uri.scheme == "https"
      http.open_timeout = @open_timeout
      http.read_timeout = @read_timeout
      http.write_timeout = @read_timeout

      http
    end
  end
end
