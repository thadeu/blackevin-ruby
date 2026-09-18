# frozen_string_literal: true

module Blackevin
  class Rest
    # The channels of one client. +get+ returns the same object for the same name.
    class Channels
      # @param client [Blackevin::Rest, nil] default: a new one, from the configuration
      def initialize(client: nil)
        @client = Rest.resolve(client)
        @channels = {}
        @mutex = Mutex.new
      end

      # @param name [String]
      # @return [Blackevin::Rest::Channel]
      def get(name)
        name = name.to_s

        raise ConfigurationError, 'a channel needs a name' if name.empty?

        @mutex.synchronize { @channels[name] ||= Channel.new(name, client: @client) }
      end

      alias_method :[], :get
    end
  end
end
