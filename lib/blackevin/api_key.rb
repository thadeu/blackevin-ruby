# frozen_string_literal: true

module Blackevin
  # An API key, written +secret.keyId+.
  #
  # Split on the LAST dot: the keyId carries none, so everything before it is
  # the secret verbatim. Same rules as the node, pinned by the contract fixtures.
  class ApiKey
    attr_reader :key_name, :secret

    # @param raw [String] the key as copied from the console
    # @raise [Blackevin::ConfigurationError] when it is not +secret.keyId+
    def self.parse(raw)
      case raw.to_s.strip.rpartition('.')
      in [secret, '.', key_name] unless secret.empty? || key_name.empty?
        new(key_name, secret)
      else
        raise ConfigurationError, 'malformed API key: expected secret.keyId'
      end
    end

    def initialize(key_name, secret)
      @key_name = key_name
      @secret = secret
    end

    # Never print the secret: this object ends up in logs and error reports.
    def inspect = "#<Blackevin::ApiKey key_name=#{key_name.inspect} secret=[FILTERED]>"
  end
end
