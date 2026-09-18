# frozen_string_literal: true

require 'uri'
require 'yaml'

# Every operation the OpenAPI file offers an SDK must exist here, under the
# method and path the file states. An operation added to the contract fails this
# suite until the gem implements it.
RSpec.describe 'spec/contract/openapi.yaml' do
  document = YAML.safe_load_file(File.join(ContractFixtures::ROOT, 'openapi.yaml'))

  sdk_tags = %w[auth channels clients queues]

  calls = {
    'requestToken' => ->(rest) { rest.auth.request_token(keyName: 'kid', timestamp: 1, nonce: 'n' * 16) },
    'publish' => ->(rest) { rest.channels.get('room').publish('event', 1) },
    'channelHistory' => ->(rest) { rest.channels.get('room').history },
    'presenceGet' => ->(rest) { rest.channels.get('room').presence.get },
    'presenceHistory' => ->(rest) { rest.channels.get('room').presence.history },
    'forceDisconnect' => ->(rest) { rest.clients.disconnect('bob') },
    'listQueues' => ->(rest) { rest.queues.list },
    'upsertQueue' => ->(rest) { rest.queues.upsert(name: 'inbox') },
    'updateQueue' => ->(rest) { rest.queues.update('q1', enabled: false) },
    'deleteQueue' => ->(rest) { rest.queues.delete('q1') },
    'listQueueRules' => ->(rest) { rest.queues.rules('q1') },
    'createQueueRule' => ->(rest) { rest.queues.add_rule('q1', source_pattern: 'room:*') },
    'deleteQueueRule' => ->(rest) { rest.queues.delete_rule('q1', 'r1') }
  }

  responses = {
    'requestToken' => {'token' => 'jwt'},
    'upsertQueue' => {'queue' => {'id' => 'q1'}},
    'updateQueue' => {'queue' => {'id' => 'q1'}},
    'createQueueRule' => {'rule' => {'id' => 'r1'}}
  }

  operations = document.fetch('paths').flat_map do |path, item|
    item.slice('get', 'post', 'put', 'patch', 'delete').map do |verb, operation|
      {path: path, verb: verb.upcase, id: operation.fetch('operationId'), tags: operation.fetch('tags')}
    end
  end

  sdk_operations = operations.select { |operation| (operation[:tags] & sdk_tags).any? }

  it 'lists SDK operations at all' do
    expect(sdk_operations.size).to be >= 13
  end

  sdk_operations.each do |operation|
    it "#{operation[:id]} sends #{operation[:verb]} #{operation[:path]}" do
      call = calls[operation[:id]]

      expect(call).not_to be_nil, "the contract has #{operation[:id]} and this SDK does not implement it"

      transport = RecordingTransport.new(body: responses.fetch(operation[:id], {}))

      call.call(Blackevin::Rest.new(key: 'secret.kid', rest_endpoint: 'http://node.test', transport: transport))

      template = Regexp.new("\\A#{Regexp.escape(operation[:path]).gsub(/\\\{[^}]+\\\}/, '[^/]+')}\\z")

      expect(transport.last.method).to eq(operation[:verb])
      expect(URI.parse(transport.last.url).path).to match(template)
    end
  end

  it 'implements nothing the contract does not describe' do
    expect(calls.keys - sdk_operations.map { |operation| operation[:id] }).to be_empty
  end
end
