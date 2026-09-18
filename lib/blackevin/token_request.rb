# frozen_string_literal: true

require "json"
require "openssl"

module Blackevin
  # What your server hands a browser instead of the API key: signed, scoped to a
  # capability, and dead after its ttl. The browser exchanges it for a token.
  #
  # Serialises to the wire shape, so a controller can render it as is:
  #
  #   render json: Blackevin.rest.auth.create_token_request(client_id: current_user.id)
  class TokenRequest
    # The field ORDER and the newline after each are the wire contract. The node
    # recomputes exactly this text to verify, and a reordering breaks every
    # token with an error ("invalid token request mac") that names nothing.
    SIGNED_FIELDS = %i[key_name ttl capability client_id timestamp nonce].freeze

    WIRE_NAMES = {
      key_name: "keyName",
      ttl: "ttl",
      capability: "capability",
      client_id: "clientId",
      timestamp: "timestamp",
      nonce: "nonce",
      mac: "mac"
    }.freeze

    attr_reader :key_name, :ttl, :capability, :client_id, :timestamp, :nonce, :mac

    # @param key_name [String]
    # @param timestamp [Integer] milliseconds since the epoch
    # @param nonce [String] single use, at least 16 characters
    # @param ttl [Integer, nil] milliseconds
    # @param capability [String, nil] a capability map serialised as JSON
    # @param client_id [String, nil]
    # @param mac [String, nil]
    def initialize(key_name:, timestamp:, nonce:, ttl: nil, capability: nil, client_id: nil, mac: nil)
      @key_name = key_name
      @ttl = ttl
      @capability = capability
      @client_id = client_id
      @timestamp = timestamp
      @nonce = nonce
      @mac = mac
    end

    # Builds one from a wire hash (camelCase keys) or a Ruby hash (snake_case).
    #
    # @param hash [Hash]
    # @return [Blackevin::TokenRequest]
    def self.from_h(hash)
      values = WIRE_NAMES.to_h do |attribute, wire|
        [attribute, hash[wire] || hash[wire.to_sym] || hash[attribute] || hash[attribute.to_s]]
      end

      new(**values)
    end

    # The exact text the MAC is computed over.
    def signing_text = SIGNED_FIELDS.map { "#{public_send(_1)}\n" }.join

    # @param secret [String] the secret half of the API key
    # @return [Blackevin::TokenRequest] a copy carrying the MAC
    def sign(secret)
      digest = OpenSSL::HMAC.digest("SHA256", secret, signing_text)

      self.class.new(**attributes, mac: [digest].pack("m0"))
    end

    # The wire shape: camelCase keys, absent fields omitted.
    #
    # @return [Hash{String => Object}]
    def to_h
      WIRE_NAMES.each_with_object({}) do |(attribute, wire), hash|
        value = public_send(attribute)

        hash[wire] = value unless value.nil?
      end
    end

    # Rails' +render json:+ calls this, so the wire shape survives it too.
    def as_json(*) = to_h

    def to_json(...) = to_h.to_json(...)

    def ==(other) = other.is_a?(self.class) && other.to_h == to_h

    # Pattern matching, with the Ruby names: +in {client_id:, ttl:}+.
    def deconstruct_keys(_keys) = attributes.merge(mac: mac)

    private

    def attributes = SIGNED_FIELDS.to_h { [_1, public_send(_1)] }
  end
end
