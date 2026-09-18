# frozen_string_literal: true

module Blackevin
  # Process-wide defaults for {Blackevin.rest}.
  #
  #   Blackevin.configure do |config|
  #     config.key = ENV.fetch("BLACKEVIN_KEY")
  #   end
  #
  # Nothing here is required: with +BLACKEVIN_KEY+ in the environment,
  # {Blackevin.rest} works unconfigured.
  class Configuration
    ENV_KEY = "BLACKEVIN_KEY"

    # @return [String, nil] the full API key, +secret.keyId+
    attr_writer :key

    # @return [String, nil] REST base URL; see {Blackevin::Endpoints}
    attr_accessor :rest_endpoint

    # @return [String, nil] socket endpoint, read only to derive the REST base for a single-origin node
    attr_accessor :endpoint

    # @return [Numeric] seconds
    attr_accessor :open_timeout, :read_timeout

    # @return [#call, nil] replaces the Net::HTTP transport
    attr_accessor :transport

    def initialize
      @open_timeout = 5
      @read_timeout = 10
    end

    def key = @key || ENV[ENV_KEY]

    # @return [Hash] the options {Blackevin::Rest.new} takes
    def to_rest_options
      {
        key: key,
        rest_endpoint: rest_endpoint,
        endpoint: endpoint,
        open_timeout: open_timeout,
        read_timeout: read_timeout,
        transport: transport
      }
    end
  end
end
