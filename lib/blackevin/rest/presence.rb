# frozen_string_literal: true

module Blackevin
  class Rest
    # Presence on one channel.
    class Presence
      # @param channel [String] the channel's name
      # @param client [Blackevin::Rest, nil] default: a new one, from the configuration
      def initialize(channel, client: nil)
        raise ConfigurationError, 'presence needs a channel name' if channel.to_s.empty?

        @client = Rest.resolve(client)
        @path = "/api/channels/#{Rest.escape(channel)}/presence"
      end

      # Who is present now.
      #
      # @return [Array<Blackevin::PresenceMember>]
      # @raise [Blackevin::Error]
      def get
        body = @client.request('presence get', 'GET', @path)

        Array(body['members']).map { PresenceMember.from_h(_1) }
      end

      # Past enter, leave and update events, newest first.
      #
      # @param limit [Integer] clamped by the node to 1..1000
      # @return [Array<Blackevin::PresenceEvent>]
      # @raise [Blackevin::Error]
      def history(limit: DEFAULT_HISTORY_LIMIT)
        body = @client.request('presence history', 'GET', "#{@path}/history", query: {'limit' => limit})

        Array(body['events']).map { PresenceEvent.from_h(_1) }
      end
    end
  end
end
