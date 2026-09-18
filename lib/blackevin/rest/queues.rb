# frozen_string_literal: true

module Blackevin
  class Rest
    # Account queues and the rules that feed them. The key needs +amqp-subscribe+.
    #
    # A queue is addressed by its id, never its name: the name is the physical
    # queue on the broker, so a 404 must mean "no such queue".
    class Queues
      # @param client [Blackevin::Rest, nil] default: a new one, from the configuration
      def initialize(client: nil)
        @client = Rest.resolve(client)
      end

      # @param all [Boolean] include paused queues
      # @return [Array<Blackevin::Queue>]
      # @raise [Blackevin::Error]
      def list(all: false)
        body = @client.request('list queues', 'GET', '/api/queues', query: all ? {'all' => '1'} : nil)

        Array(body['queues']).map { Queue.from_h(_1) }
      end

      # Creates a queue, or edits the one already holding this name. Only a new
      # queue counts against the plan's ceiling.
      #
      # @param name [String]
      # @param max_length [Integer, nil]
      # @param enabled [Boolean]
      # @return [Blackevin::Queue]
      # @raise [Blackevin::Error] with reason "queue_limit" at the plan's ceiling
      def upsert(name:, max_length: nil, enabled: true)
        body = {'name' => name.to_s, 'enabled' => enabled}
        body['maxLength'] = max_length unless max_length.nil?

        Queue.from_h(@client.request('upsert queue', 'POST', '/api/queues', body: body).fetch('queue'))
      end

      alias_method :create, :upsert

      # Pauses, resumes or resizes. Omitted arguments are left as they are;
      # +max_length: nil+ passed explicitly removes the bound.
      #
      # @param id [String]
      # @param enabled [Boolean]
      # @param max_length [Integer, nil]
      # @return [Blackevin::Queue]
      # @raise [Blackevin::Error]
      def update(id, **changes)
        unknown = changes.except(:enabled, :max_length).keys

        raise ArgumentError, "unknown keywords: #{unknown.join(', ')}" unless unknown.empty?

        body = {}
        body['enabled'] = changes[:enabled] if changes.key?(:enabled)
        body['maxLength'] = changes[:max_length] if changes.key?(:max_length)

        Queue.from_h(@client.request('update queue', 'PATCH', queue_path(id), body: body).fetch('queue'))
      end

      # Deletes the queue and whatever is waiting in it.
      #
      # @param id [String]
      # @return [String] the name of the deleted queue
      # @raise [Blackevin::Error]
      def delete(id)
        @client.request('delete queue', 'DELETE', queue_path(id))['deleted']
      end

      # @param id [String] the queue's id
      # @return [Array<Blackevin::QueueRule>]
      # @raise [Blackevin::Error]
      def rules(id)
        body = @client.request('list queue rules', 'GET', "#{queue_path(id)}/rules")

        Array(body['rules']).map { QueueRule.from_h(_1) }
      end

      # Copies messages from channels matching the pattern into the queue.
      #
      # @param id [String] the queue's id
      # @param source_pattern [String] a channel name or wildcard pattern
      # @param filter [String, nil]
      # @return [Blackevin::QueueRule]
      # @raise [Blackevin::Error]
      def add_rule(id, source_pattern:, filter: nil)
        body = {'sourcePattern' => source_pattern.to_s}
        body['filter'] = filter unless filter.nil?

        QueueRule.from_h(@client.request('add queue rule', 'POST', "#{queue_path(id)}/rules", body: body).fetch('rule'))
      end

      # Stops the copies at the source. Messages already enqueued stay.
      #
      # @param id [String] the queue's id
      # @param rule_id [String]
      # @return [true]
      # @raise [Blackevin::Error]
      def delete_rule(id, rule_id)
        @client.request('delete queue rule', 'DELETE', "#{queue_path(id)}/rules/#{Rest.escape(rule_id)}")

        true
      end

      private

      def queue_path(id)
        raise ConfigurationError, 'a queue is addressed by its id' if id.to_s.empty?

        "/api/queues/#{Rest.escape(id)}"
      end
    end
  end
end
