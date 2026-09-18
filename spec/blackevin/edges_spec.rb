# frozen_string_literal: true

# The quiet paths: wrong input from the caller, absent fields from the server.
RSpec.describe 'edges' do
  let(:transport) { RecordingTransport.new(body: body) }
  let(:body) { {} }
  let(:bk) { Blackevin::Rest.new(key: 'secret.kid', rest_endpoint: 'http://node.test', transport: transport) }

  describe 'a 200 whose body is JSON but not an object' do
    let(:body) { '[]' }

    it 'reads as an empty result rather than raising' do
      expect(bk.channels.get('room').history).to eq([])
    end
  end

  it 'accepts a signed TokenRequest object in request_token, not only a Hash' do
    transport = RecordingTransport.new(body: {'token' => 'jwt'})
    client = Blackevin::Rest.new(key: 'secret.kid', rest_endpoint: 'http://node.test', transport: transport)

    client.auth.request_token(client.auth.create_token_request(client_id: 'bob'))

    expect(JSON.parse(transport.last.body)).to include('keyName' => 'kid', 'clientId' => 'bob')
    expect(transport.last.headers).not_to have_key('authorization')
  end

  it 'refuses anything else in request_token, in words' do
    expect { bk.auth.request_token('not a request') }
      .to raise_error(Blackevin::ConfigurationError, /TokenRequest or a Hash, got String/)
  end

  it 'refuses a TokenEndpoint block that returns neither a Hash nor nil' do
    endpoint = Blackevin::TokenEndpoint.new(rest: bk) { 'bob' }

    expect { endpoint.call('REQUEST_METHOD' => 'GET') }
      .to raise_error(Blackevin::ConfigurationError, /must return a Hash or nil, got String/)
  end

  it 'treats false from the TokenEndpoint block as a refusal' do
    status, = Blackevin::TokenEndpoint.new(rest: bk) { false }.call('REQUEST_METHOD' => 'GET')

    expect(status).to eq(401)
  end

  it 'refuses an empty client_id or queue id before any request' do
    expect { bk.clients.disconnect('') }.to raise_error(Blackevin::ConfigurationError)
    expect { bk.queues.delete(nil) }.to raise_error(Blackevin::ConfigurationError)
    expect(transport.requests).to be_empty
  end

  it 'sends a rule filter only when one is given' do
    transport = RecordingTransport.new(body: {'rule' => {'id' => 'r1'}})
    client = Blackevin::Rest.new(key: 'secret.kid', transport: transport)

    client.queues.add_rule('q1', source_pattern: 'room:*', filter: 'name == "order"')

    expect(JSON.parse(transport.last.body)).to eq('sourcePattern' => 'room:*', 'filter' => 'name == "order"')
  end

  it 'leaves times nil when the server sent no timestamp' do
    details = Blackevin::TokenDetails.from_h('token' => 'jwt')

    expect(details.expires_at).to be_nil
    expect(details.issued_at).to be_nil
    expect(details).not_to be_expired
    expect(Blackevin::Message.from_h({}).time).to be_nil
    expect(Blackevin::PresenceEvent.from_h({}).time).to be_nil
    expect(Blackevin::Queue.from_h('enabled' => false)).not_to be_enabled
  end

  it 'knows an expired token from a live one' do
    now = Time.at(1_767_225_600)
    details = Blackevin::TokenDetails.from_h('token' => 'jwt', 'issued' => 1_767_225_000_000, 'expires' => 1_767_225_600_000)

    expect(details.issued_at).to eq(Time.at(1_767_225_000))
    expect(details.expired?(now)).to be(true)
    expect(details.expired?(now - 1)).to be(false)
    expect(JSON.parse(details.to_json)).to include('token' => 'jwt', 'expires' => 1_767_225_600_000)
  end

  it 'sends a request without a body or an Authorization when neither applies' do
    Blackevin::Rest.new(rest_endpoint: 'http://node.test', transport: transport).channels.get('room').history

    expect(transport.last.headers).not_to have_key('authorization')
    expect(transport.last.headers).not_to have_key('content-type')
    expect(transport.last.body).to be_nil
  end
end
