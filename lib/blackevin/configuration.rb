# frozen_string_literal: true

module Blackevin
  # The defaults a new {Blackevin::Rest} starts from. An argument given to
  # +Rest.new+ wins over these, and these win over the environment.
  #
  #   Blackevin.configure do |config|
  #     config.key = ENV.fetch("BLACKEVIN_KEY")
  #   end
  #
  # Nothing here is required: with +BLACKEVIN_KEY+ in the environment,
  # +Blackevin::Rest.new+ works unconfigured.
  class Configuration
    ENV_KEY = 'BLACKEVIN_KEY'

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
  end
end
