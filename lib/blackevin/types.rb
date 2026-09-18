# frozen_string_literal: true

module Blackevin
  # A stored message, as +channel.history+ returns it.
  Message = Struct.new(:channel, :name, :data, :connection_id, :timestamp, keyword_init: true) do
    def self.from_h(hash)
      new(
        channel: hash['channel'],
        name: hash['name'],
        data: hash['data'],
        connection_id: hash['connectionId'],
        timestamp: hash['timestamp']
      )
    end

    # @return [Time, nil]
    def time = timestamp&.then { Time.at(_1 / 1000.0) }
  end

  # Someone present on a channel right now.
  PresenceMember = Struct.new(:client_id, :connection_id, :data, :updated_at, keyword_init: true) do
    def self.from_h(hash)
      new(
        client_id: hash['clientId'],
        connection_id: hash['connectionId'],
        data: hash['data'],
        updated_at: hash['updatedAt']
      )
    end
  end

  # A past enter, leave or update.
  PresenceEvent = Struct.new(:channel, :action, :client_id, :connection_id, :data, :timestamp, keyword_init: true) do
    def self.from_h(hash)
      new(
        channel: hash['channel'],
        action: hash['action'],
        client_id: hash['clientId'],
        connection_id: hash['connectionId'],
        data: hash['data'],
        timestamp: hash['timestamp']
      )
    end

    # @return [Time, nil]
    def time = timestamp&.then { Time.at(_1 / 1000.0) }
  end

  # An account queue. Addressed by {#id} everywhere; {#name} is immutable and
  # is what a worker consumes from on the broker.
  Queue = Struct.new(:id, :account_id, :name, :max_length, :enabled, keyword_init: true) do
    def self.from_h(hash)
      new(
        id: hash['id'],
        account_id: hash['accountId'],
        name: hash['name'],
        max_length: hash['maxLength'],
        enabled: hash['enabled']
      )
    end

    def enabled? = enabled == true
  end

  # Copies messages from channels matching {#source_pattern} into a queue.
  QueueRule = Struct.new(:id, :account_id, :queue_name, :source_pattern, :filter, :enabled, keyword_init: true) do
    def self.from_h(hash)
      new(
        id: hash['id'],
        account_id: hash['accountId'],
        queue_name: hash['queueName'],
        source_pattern: hash['sourcePattern'],
        filter: hash['filter'],
        enabled: hash['enabled']
      )
    end
  end
end
