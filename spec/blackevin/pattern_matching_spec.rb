# frozen_string_literal: true

RSpec.describe 'pattern matching' do
  def classify(error)
    case error
    in {reason: 'queue_limit'} then :upgrade
    in {status_code: 401 | 403} then :credentials
    in {status_code: nil} then :network
    else :other
    end
  end

  it 'branches a rescue by the shape of the error' do
    expect(classify(Blackevin::Error.new('x', 429, 'queue_limit'))).to eq(:upgrade)
    expect(classify(Blackevin::Error.new('x', 403))).to eq(:credentials)
    expect(classify(Blackevin::ConnectionError.new('x'))).to eq(:network)
    expect(classify(Blackevin::Error.new('x', 500))).to eq(:other)
  end

  it 'destructures a TokenRequest with the Ruby names' do
    request = Blackevin::Rest.new(key: 'secret.kid').auth.create_token_request(client_id: 7, ttl: 1000)

    case request
    in {key_name: String => key_name, client_id: String => client_id, ttl: Integer => ttl, mac: String}
      expect([key_name, client_id, ttl]).to eq(['kid', '7', 1000])
    end
  end

  it 'destructures TokenDetails and a Message, and never binds the token' do
    details = Blackevin::TokenDetails.from_h('token' => 'jwt', 'keyName' => 'kid', 'clientId' => 'bob')
    message = Blackevin::Message.from_h('channel' => 'room', 'name' => 'e', 'data' => {'n' => 1})

    expect(details.deconstruct_keys(nil)).not_to have_key(:token)

    case [details, message]
    in [{client_id: 'bob'}, {name: 'e', data: Hash => data}]
      expect(data).to eq('n' => 1)
    end
  end

  it 'refuses a capability that is neither a map nor a string, in words' do
    expect { Blackevin::Rest.new(key: 'secret.kid').auth.create_token_request(capability: 42) }
      .to raise_error(Blackevin::ConfigurationError, /capability/)
  end
end
