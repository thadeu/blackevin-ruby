# frozen_string_literal: true

require_relative "blackevin/version"
require_relative "blackevin/errors"
require_relative "blackevin/api_key"
require_relative "blackevin/endpoints"
require_relative "blackevin/token_request"
require_relative "blackevin/token_details"
require_relative "blackevin/types"
require_relative "blackevin/transport"
require_relative "blackevin/configuration"
require_relative "blackevin/rest"
require_relative "blackevin/rest/auth"
require_relative "blackevin/rest/channels"
require_relative "blackevin/rest/clients"
require_relative "blackevin/rest/queues"
require_relative "blackevin/token_endpoint"

# Server-side SDK for Blackevin: sign token requests, publish, read history and
# presence, manage queues. Standard library only.
#
#   Blackevin.configure { |config| config.key = ENV.fetch("BLACKEVIN_KEY") }
#
#   Blackevin.rest.channels.get("room:42").publish("greeting", {text: "hi"})
module Blackevin
  @mutex = Mutex.new

  class << self
    # @return [Blackevin::Configuration]
    def configuration
      @mutex.synchronize { @configuration ||= Configuration.new }
    end

    # @yieldparam config [Blackevin::Configuration]
    # @return [Blackevin::Configuration]
    def configure
      yield configuration

      @mutex.synchronize { @rest = nil }

      configuration
    end

    # The process-wide client, built from {configuration} on first use.
    #
    # @return [Blackevin::Rest]
    def rest
      options = configuration.to_rest_options

      @mutex.synchronize { @rest ||= Rest.new(**options) }
    end

    # Forgets the configuration and the client. For test suites.
    def reset!
      @mutex.synchronize do
        @configuration = nil
        @rest = nil
      end
    end
  end
end

require_relative "blackevin/railtie" if defined?(Rails::Railtie)
