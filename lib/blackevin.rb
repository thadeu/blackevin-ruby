# frozen_string_literal: true

require_relative 'blackevin/version'
require_relative 'blackevin/errors'
require_relative 'blackevin/api_key'
require_relative 'blackevin/endpoints'
require_relative 'blackevin/token_request'
require_relative 'blackevin/token_details'
require_relative 'blackevin/types'
require_relative 'blackevin/transport'
require_relative 'blackevin/configuration'
require_relative 'blackevin/rest'
require_relative 'blackevin/rest/auth'
require_relative 'blackevin/rest/presence'
require_relative 'blackevin/rest/channel'
require_relative 'blackevin/rest/channels'
require_relative 'blackevin/rest/clients'
require_relative 'blackevin/rest/queues'
require_relative 'blackevin/token_endpoint'

# Server-side SDK for Blackevin: sign token requests, publish, read history and
# presence, manage queues. Standard library only.
#
#   bk = Blackevin::Rest.new
#
#   bk.channels.get('room:42').publish('greeting', {text: 'hi'})
#
# There is no process-wide client. {Blackevin.configure} only holds the defaults
# a new {Blackevin::Rest} starts from.
module Blackevin
  @mutex = Mutex.new

  class << self
    # @return [Blackevin::Configuration]
    def configuration
      @mutex.synchronize { @configuration ||= Configuration.new }
    end

    # Sets the defaults every later {Blackevin::Rest.new} starts from. It builds
    # nothing and calls nothing: a client already created keeps what it was given.
    #
    # @yieldparam config [Blackevin::Configuration]
    # @return [Blackevin::Configuration]
    def configure
      yield configuration

      configuration
    end

    # Forgets the configuration. For test suites.
    def reset!
      @mutex.synchronize { @configuration = nil }
    end
  end
end

require_relative 'blackevin/railtie' if defined?(Rails::Railtie)
