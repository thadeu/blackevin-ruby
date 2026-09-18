# frozen_string_literal: true

module Blackevin
  class Rest
    # One channel: publish, history, presence.
    class Channel
      # @return [String]
      attr_reader :name

      # @return [Blackevin::Rest::Presence]
      attr_reader :presence

      # @param name [String]
      # @param client [Blackevin::Rest, nil] default: a new one, from the configuration
      def initialize(name, client: nil)
        @name = name.to_s

        raise ConfigurationError, 'a channel needs a name' if @name.empty?

        @client = Rest.resolve(client)
        @path = "/api/channels/#{Rest.escape(@name)}"
        @presence = Presence.new(@name, client: @client)
      end

      # Publishes without a socket — from a job, a cron, or a webhook arriving
      # at your backend. Subscribers, account queues and integrations see it
      # exactly as they see a socket publish.
      #
      # @param event [String, Symbol] the event name
      # @param data [Object, nil] anything JSON can carry
      # @return [true]
      # @raise [Blackevin::Error]
      def publish(event, data = nil)
        body = {'name' => event.to_s}
        body['data'] = data unless data.nil?

        @client.request('publish', 'POST', "#{@path}/publish", body: body)

        true
      end

      # Stored messages, newest first.
      #
      # @param limit [Integer] clamped by the node to 1..1000
      # @return [Array<Blackevin::Message>]
      # @raise [Blackevin::Error]
      def history(limit: DEFAULT_HISTORY_LIMIT)
        body = @client.request('history', 'GET', "#{@path}/history", query: {'limit' => limit})

        Array(body['messages']).map { Message.from_h(_1) }
      end

      def inspect = "#<Blackevin::Rest::Channel name=#{name.inspect}>"
    end
  end
end
