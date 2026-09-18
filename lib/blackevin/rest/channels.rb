# frozen_string_literal: true

module Blackevin
  class Rest
    # The channels of one client. +get+ returns the same object for the same name.
    class Channels
      def initialize(rest)
        @rest = rest
        @channels = {}
        @mutex = Mutex.new
      end

      # @param name [String]
      # @return [Blackevin::Rest::Channel]
      def get(name)
        name = name.to_s

        raise ConfigurationError, 'a channel needs a name' if name.empty?

        @mutex.synchronize { @channels[name] ||= Channel.new(@rest, name) }
      end

      alias_method :[], :get
    end

    # One channel: publish, history, presence.
    class Channel
      DEFAULT_HISTORY_LIMIT = 100

      # @return [String]
      attr_reader :name

      # @return [Blackevin::Rest::Presence]
      attr_reader :presence

      def initialize(rest, name)
        @rest = rest
        @name = name
        @path = "/api/channels/#{Rest.escape(name)}"
        @presence = Presence.new(rest, @path)
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

        @rest.request('publish', 'POST', "#{@path}/publish", body: body)

        true
      end

      # Stored messages, newest first.
      #
      # @param limit [Integer] clamped by the node to 1..1000
      # @return [Array<Blackevin::Message>]
      # @raise [Blackevin::Error]
      def history(limit: DEFAULT_HISTORY_LIMIT)
        body = @rest.request('history', 'GET', "#{@path}/history", query: {'limit' => limit})

        Array(body['messages']).map { Message.from_h(_1) }
      end

      def inspect = "#<Blackevin::Rest::Channel name=#{name.inspect}>"
    end

    # Presence on one channel.
    class Presence
      def initialize(rest, channel_path)
        @rest = rest
        @path = "#{channel_path}/presence"
      end

      # Who is present now.
      #
      # @return [Array<Blackevin::PresenceMember>]
      # @raise [Blackevin::Error]
      def get
        body = @rest.request('presence get', 'GET', @path)

        Array(body['members']).map { PresenceMember.from_h(_1) }
      end

      # Past enter, leave and update events, newest first.
      #
      # @param limit [Integer] clamped by the node to 1..1000
      # @return [Array<Blackevin::PresenceEvent>]
      # @raise [Blackevin::Error]
      def history(limit: Channel::DEFAULT_HISTORY_LIMIT)
        body = @rest.request('presence history', 'GET', "#{@path}/history", query: {'limit' => limit})

        Array(body['events']).map { PresenceEvent.from_h(_1) }
      end
    end
  end
end
