# frozen_string_literal: true

RSpec.describe Blackevin::Rest do
  let(:transport) { RecordingTransport.new(body: body) }
  let(:body) { {} }
  let(:rest) { described_class.new(key: 'secret.kid', rest_endpoint: 'http://node.test', transport: transport) }

  it 'returns the same channel object for the same name' do
    expect(rest.channels.get('room')).to be(rest.channels['room'])
  end

  it 'refuses a channel without a name before any request' do
    expect { rest.channels.get('') }.to raise_error(Blackevin::ConfigurationError)
    expect(transport.requests).to be_empty
  end

  it 'accepts an Integer client_id, as a Rails model id is' do
    expect(rest.auth.create_token_request(client_id: 42).client_id).to eq('42')
  end

  it 'never prints the secret or a token' do
    details = Blackevin::TokenDetails.from_h('token' => 'jwt-credential', 'keyName' => 'kid')

    expect(Blackevin::ApiKey.parse('s3cr3t.kid').inspect).not_to include('s3cr3t')
    expect(details.inspect).not_to include('jwt-credential')
    expect(rest.inspect).not_to include('secret')
  end

  describe 'history' do
    let(:body) { {'messages' => [{'channel' => 'room', 'name' => 'e', 'data' => 1, 'timestamp' => 1_767_225_600_000}]} }

    it 'returns messages with a Time alongside the wire timestamp' do
      message = rest.channels.get('room').history(limit: 1).first

      expect(message).to have_attributes(channel: 'room', name: 'e', data: 1, timestamp: 1_767_225_600_000)
      expect(message.time).to eq(Time.at(1_767_225_600))
    end
  end

  describe 'presence history' do
    let(:body) { {'events' => [{'channel' => 'room', 'action' => 'enter', 'clientId' => 'bob', 'connectionId' => 'c1', 'timestamp' => 5}]} }

    it 'returns events' do
      event = rest.channels.get('room').presence.history(limit: 5).first

      expect(event).to have_attributes(action: 'enter', client_id: 'bob', connection_id: 'c1')
      expect(transport.last.url).to eq('http://node.test/api/channels/room/presence/history?limit=5')
    end
  end

  describe 'clients' do
    let(:body) { {'closed' => 2} }

    it 'returns how many connections were closed' do
      expect(rest.clients.disconnect(42)).to eq(2)
      expect(transport.last.url).to eq('http://node.test/api/clients/42/connections/close')
    end
  end

  describe 'queues' do
    let(:body) { {'queue' => {'id' => 'q1', 'accountId' => 'a', 'name' => 'inbox', 'maxLength' => 10, 'enabled' => true}} }

    it 'upserts with the wire names' do
      queue = rest.queues.upsert(name: 'inbox', max_length: 10)

      expect(queue).to have_attributes(id: 'q1', name: 'inbox', max_length: 10)
      expect(queue).to be_enabled
      expect(JSON.parse(transport.last.body)).to eq('name' => 'inbox', 'maxLength' => 10, 'enabled' => true)
    end

    it 'sends only what update was given, and null to remove the bound' do
      rest.queues.update('q1', enabled: false)

      expect(JSON.parse(transport.last.body)).to eq('enabled' => false)

      rest.queues.update('q1', max_length: nil)

      expect(JSON.parse(transport.last.body)).to eq('maxLength' => nil)
    end

    it 'refuses an unknown keyword rather than dropping it' do
      expect { rest.queues.update('q1', name: 'renamed') }.to raise_error(ArgumentError, /name/)
    end

    it 'asks for paused queues with all=1' do
      rest.queues.list(all: true)

      expect(transport.last.url).to eq('http://node.test/api/queues?all=1')
    end
  end

  it 'raises when a 200 is not JSON' do
    broken = described_class.new(key: 'secret.kid', transport: RecordingTransport.new(body: '<html>'))

    expect { broken.channels.get('room').history }.to raise_error(Blackevin::Error, /not JSON/)
  end
end
