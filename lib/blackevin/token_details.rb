# frozen_string_literal: true

module Blackevin
  # The token a TokenRequest was exchanged for, and what it is good for.
  class TokenDetails
    attr_reader :token, :key_name, :issued, :expires, :capability, :client_id

    # @param hash [Hash] the wire body of +requestToken+
    # @return [Blackevin::TokenDetails]
    def self.from_h(hash)
      new(
        token: hash['token'],
        key_name: hash['keyName'],
        issued: hash['issued'],
        expires: hash['expires'],
        capability: hash['capability'],
        client_id: hash['clientId']
      )
    end

    def initialize(token:, key_name: nil, issued: nil, expires: nil, capability: nil, client_id: nil)
      @token = token
      @key_name = key_name
      @issued = issued
      @expires = expires
      @capability = capability
      @client_id = client_id
    end

    # @return [Time, nil]
    def expires_at = expires&.then { Time.at(_1 / 1000.0) }

    # @return [Time, nil]
    def issued_at = issued&.then { Time.at(_1 / 1000.0) }

    def expired?(now = Time.now) = !expires.nil? && expires_at <= now

    # The wire shape, as the node sent it.
    def to_h
      {
        'token' => token,
        'keyName' => key_name,
        'issued' => issued,
        'expires' => expires,
        'capability' => capability,
        'clientId' => client_id
      }.compact
    end

    def as_json(*) = to_h

    def to_json(...) = to_h.to_json(...)

    # Pattern matching, with the Ruby names. The token itself is left out on
    # purpose: a pattern's bindings end up in logs more easily than a reader.
    def deconstruct_keys(_keys)
      { key_name: key_name, issued: issued, expires: expires, capability: capability, client_id: client_id }
    end

    # The token is a credential; keep it out of logs.
    def inspect
      "#<Blackevin::TokenDetails key_name=#{key_name.inspect} client_id=#{client_id.inspect} expires=#{expires.inspect} token=[FILTERED]>"
    end
  end
end
