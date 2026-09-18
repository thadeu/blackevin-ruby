# frozen_string_literal: true

require 'json'

module Blackevin
  # The REST client: no socket, no reconnection, no state beyond its options.
  #
  #   bk = Blackevin::Rest.new
  #
  #   bk.auth.create_token_request(client_id: 'bob')
  #   bk.channels.get('room:42').publish('greeting', {text: 'hi'})
  #
  # Each part also stands alone, so nothing forces a chain through this class:
  #
  #   Blackevin::Rest::Auth.new.create_token_request(client_id: 'bob')
  #   Blackevin::Rest::Channel.new('room:42').publish('greeting', {text: 'hi'})
  #   Blackevin::Rest::Queues.new.list
  #
  # Each takes an optional +client:+ and builds a +Blackevin::Rest.new+ without one.
  #
  # Every option falls back to {Blackevin.configuration}, and the key falls back
  # from there to +BLACKEVIN_KEY+, so +new+ with no arguments is the usual call.
  # Creating one is cheap — it opens nothing — so there is no need to share it.
  #
  # Safe to share across threads: every call opens its own connection and the
  # instance holds nothing mutable but a channel cache behind a mutex.
  class Rest
    DEFAULT_HISTORY_LIMIT = 100

    USER_AGENT = "blackevin-ruby/#{VERSION} ruby/#{RUBY_VERSION}"

    # @return [Blackevin::Rest::Auth]
    attr_reader :auth

    # @return [Blackevin::Rest::Channels]
    attr_reader :channels

    # @return [Blackevin::Rest::Clients]
    attr_reader :clients

    # @return [Blackevin::Rest::Queues]
    attr_reader :queues

    # @return [String] the resolved REST base URL
    attr_reader :rest_endpoint

    # @param key [String, nil] full API key +secret.keyId+; required to sign token requests.
    #   Default: the configured key, then +BLACKEVIN_KEY+
    # @param token [String, nil] a token, when acting as one client rather than as the account
    # @param rest_endpoint [String, nil] overrides the resolved REST host
    # @param endpoint [String, nil] socket endpoint; read only to derive the REST base
    # @param open_timeout [Numeric, nil] seconds; default from the configuration (5)
    # @param read_timeout [Numeric, nil] seconds; default from the configuration (10)
    # @param transport [#call, nil] replaces Net::HTTP; receives a {Request}, returns a {Response}
    # @param clock [#call] returns milliseconds since the epoch; injected for tests
    # @param nonce [#call] returns a fresh nonce; injected for tests
    # @param env [#[]] where the endpoint variables are read from
    def initialize(key: nil, token: nil, rest_endpoint: nil, endpoint: nil, open_timeout: nil, read_timeout: nil,
      transport: nil, clock: nil, nonce: nil, env: ENV)
      defaults = Blackevin.configuration

      @key = key || defaults.key
      @token = token

      @rest_endpoint = Endpoints.resolve(
        endpoint: endpoint || defaults.endpoint,
        rest_endpoint: rest_endpoint || defaults.rest_endpoint,
        env: env
      ).rest_endpoint

      @transport = transport || defaults.transport || Transport.new(
        open_timeout: open_timeout || defaults.open_timeout,
        read_timeout: read_timeout || defaults.read_timeout
      )

      @auth = Auth.new(client: self, clock: clock, nonce: nonce)
      @channels = Channels.new(client: self)
      @clients = Clients.new(client: self)
      @queues = Queues.new(client: self)
    end

    # @return [Blackevin::ApiKey]
    # @raise [Blackevin::ConfigurationError] when no key was given, or it is malformed
    def api_key
      raise ConfigurationError, 'this call needs the API key: pass key:, set it in Blackevin.configure, or set BLACKEVIN_KEY' if @key.to_s.strip.empty?

      ApiKey.parse(@key)
    end

    # A token wins over a key: a client acting as one user must not silently
    # act as the whole account.
    #
    # @return [String, nil]
    def authorization_header
      return "Bearer #{@token}" if @token
      return nil if @key.nil?

      "Basic #{[@key].pack('m0')}"
    end

    # What every resource class does with its +client:+ argument: use the one it
    # was given, or build one from the configuration.
    #
    # @api private
    def self.resolve(client)
      return new if client.nil?
      return client if client.respond_to?(:request) && client.respond_to?(:api_key)

      raise ConfigurationError, "client: must be a Blackevin::Rest, got #{client.class}"
    end

    # @api private
    def request(what, method, path, query: nil, body: nil, authorize: true)
      headers = {'accept' => 'application/json', 'user-agent' => USER_AGENT}
      authorization = authorize ? authorization_header : nil

      headers['authorization'] = authorization if authorization
      headers['content-type'] = 'application/json' if body

      response = @transport.call(
        Request.new(method: method, url: url_for(path, query), headers: headers, body: body && JSON.generate(body))
      )

      raise Error.from_response(what, response.status, response.body) unless (200..299).cover?(response.status)

      parse(what, response)
    end

    # Percent-encodes one path segment so it decodes back to the exact string.
    #
    # Not form encoding: +URI.encode_www_form_component+ turns a space into "+",
    # which the node reads as a literal plus sign.
    #
    # @api private
    def self.escape(segment) = segment.to_s.b.gsub(/[^A-Za-z0-9\-._~]/) { format('%%%02X', _1.ord) }

    def inspect = "#<Blackevin::Rest rest_endpoint=#{rest_endpoint.inspect}>"

    private

    def url_for(path, query)
      return "#{rest_endpoint}#{path}" if query.nil? || query.empty?

      "#{rest_endpoint}#{path}?#{URI.encode_www_form(query)}"
    end

    def parse(what, response)
      case JSON.parse(response.body.to_s)
      in Hash => parsed then parsed
      else {}
      end
    rescue JSON::ParserError
      raise Error.new("#{what} failed: the response was not JSON", response.status)
    end
  end
end
