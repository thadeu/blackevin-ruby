# frozen_string_literal: true

require 'json'
require 'securerandom'

module Blackevin
  class Rest
    # Token requests: signing one locally, and exchanging one for a token.
    class Auth
      DEFAULT_TTL_MS = 3_600_000
      DEFAULT_CAPABILITY = {'*' => %w[subscribe publish presence history]}.freeze

      def initialize(rest, clock: nil, nonce: nil)
        @rest = rest
        @clock = clock || -> { Process.clock_gettime(Process::CLOCK_REALTIME, :millisecond) }
        @nonce = nonce || -> { SecureRandom.hex(16) }
      end

      # Signs a TokenRequest for a browser to exchange.
      #
      # Local: no network call. Your server holds the secret and hands out
      # something scoped and short-lived, so Blackevin is never on the critical
      # path of your own sign-in.
      #
      # @param client_id [String, Integer, nil] who the token will act as
      # @param ttl [Integer, nil] milliseconds; default one hour, maximum 48 hours
      # @param capability [Hash, String, nil] channel pattern to allowed operations.
      #   A Hash is serialised compactly in insertion order; a String is signed byte for byte.
      # @param timestamp [Integer, nil] milliseconds since the epoch; default now
      # @param nonce [String, nil] default random
      # @return [Blackevin::TokenRequest] signed
      # @raise [Blackevin::ConfigurationError] without a usable API key
      def create_token_request(client_id: nil, ttl: nil, capability: nil, timestamp: nil, nonce: nil)
        api_key = @rest.api_key

        request = TokenRequest.new(
          key_name: api_key.key_name,
          ttl: ttl || DEFAULT_TTL_MS,
          capability: serialise(capability),
          client_id: client_id&.to_s,
          timestamp: timestamp || @clock.call,
          nonce: nonce || @nonce.call
        )

        request.sign(api_key.secret)
      end

      # Exchanges a TokenRequest for a token.
      #
      # Usually the browser's job. A server wanting a token for its own use —
      # to act as one client under a narrow capability — does it here.
      #
      # @param token_request [Blackevin::TokenRequest, Hash]
      # @return [Blackevin::TokenDetails]
      # @raise [Blackevin::Error]
      def request_token(token_request)
        wire =
          case token_request
          in TokenRequest => signed then signed.to_h
          in Hash => hash then TokenRequest.from_h(hash).to_h
          else raise ConfigurationError, "request_token takes a TokenRequest or a Hash, got #{token_request.class}"
          end
        path = "/keys/#{Rest.escape(wire.fetch('keyName'))}/requestToken"

        TokenDetails.from_h(@rest.request('requestToken', 'POST', path, body: wire, authorize: false))
      end

      private

      def serialise(capability)
        case capability
        in String => signed_as_is then signed_as_is
        in Hash => map then JSON.generate(map)
        in nil then JSON.generate(DEFAULT_CAPABILITY)
        else raise ConfigurationError, "capability must be a Hash or a JSON String, got #{capability.class}"
        end
      end
    end
  end
end
