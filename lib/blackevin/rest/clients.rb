# frozen_string_literal: true

module Blackevin
  class Rest
    # Acting on connected clients.
    class Clients
      # @param client [Blackevin::Rest, nil] default: a new one, from the configuration
      def initialize(client: nil)
        @client = Rest.resolve(client)
      end

      # Closes every connection a client holds — for signing a user out
      # everywhere, or cutting off one you have just banned.
      #
      # @param client_id [String, Integer]
      # @return [Integer] how many connections were closed
      # @raise [Blackevin::Error]
      def disconnect(client_id)
        client_id = client_id.to_s

        raise ConfigurationError, 'disconnect needs a client_id' if client_id.empty?

        path = "/api/clients/#{Rest.escape(client_id)}/connections/close"

        @client.request('disconnect', 'POST', path)['closed'].to_i
      end
    end
  end
end
