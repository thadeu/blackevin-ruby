# frozen_string_literal: true

# Each part of the REST client stands alone: it takes an optional client: and
# builds a Blackevin::Rest from the configuration without one.
RSpec.describe 'standalone resources' do
  let(:transport) { RecordingTransport.new(body: body) }
  let(:body) { {} }

  before do
    Blackevin.configure do |config|
      config.key = 'ck_test_5f2c8a1e9b.k25b5a4'
      config.rest_endpoint = 'http://node.test'
      config.transport = transport
    end
  end

  it 'signs a token request with no Rest in sight' do
    request = Blackevin::Rest::Auth.new.create_token_request(client_id: 7)

    expect(request.key_name).to eq('k25b5a4')
    expect(request.mac).to eq(request.sign('ck_test_5f2c8a1e9b').mac)
    expect(transport.requests).to be_empty
  end

  it 'publishes from a Channel built by name' do
    Blackevin::Rest::Channel.new('room:42').publish('greeting', {text: 'hi'})

    expect(transport.last.url).to eq('http://node.test/api/channels/room%3A42/publish')
  end

  it 'reaches presence through the channel, and on its own' do
    Blackevin::Rest::Channel.new('room:42').presence.get
    Blackevin::Rest::Presence.new('room:42').history(limit: 3)

    expect(transport.requests.map(&:url)).to eq(
      %w[http://node.test/api/channels/room%3A42/presence http://node.test/api/channels/room%3A42/presence/history?limit=3]
    )
  end

  it 'covers Channels, Clients and Queues the same way' do
    Blackevin::Rest::Channels.new.get('room').history
    Blackevin::Rest::Clients.new.disconnect('bob')
    Blackevin::Rest::Queues.new.list

    expect(transport.requests.map { URI.parse(_1.url).path }).to eq(
      %w[/api/channels/room/history /api/clients/bob/connections/close /api/queues]
    )
  end

  it 'uses the client it is given instead of building one' do
    other = RecordingTransport.new
    client = Blackevin::Rest.new(key: 'secret.other', rest_endpoint: 'http://other.test', transport: other)

    Blackevin::Rest::Queues.new(client: client).list

    expect(other.last.url).to eq('http://other.test/api/queues')
    expect(other.last.headers['authorization']).to eq("Basic #{['secret.other'].pack('m0')}")
    expect(transport.requests).to be_empty
  end

  it 'shares one client down the chain: channels, channel, presence' do
    client = Blackevin::Rest.new(key: 'secret.kid', transport: transport)

    expect(Blackevin::Rest).not_to receive(:new)

    client.channels.get('room').presence.get
  end

  it 'refuses a client: that is not one, in words' do
    expect { Blackevin::Rest::Auth.new(client: 'secret.kid') }
      .to raise_error(Blackevin::ConfigurationError, /client: must be a Blackevin::Rest, got String/)
  end

  it 'refuses a Channel or a Presence without a name' do
    expect { Blackevin::Rest::Channel.new('') }.to raise_error(Blackevin::ConfigurationError)
    expect { Blackevin::Rest::Presence.new(nil) }.to raise_error(Blackevin::ConfigurationError)
  end
end
